defmodule MiniLineage.Game.HuntTest do
  @moduledoc """
  Rules §20's fight, pure: who is met, how the rounds go, and what a kill pays. Dice are pinned or
  generated, never rolled freely, so nothing here asserts on chance.
  """
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias MiniLineage.Characters.Serde
  alias MiniLineage.Game.{Actions, Clock, Constants, Hunt, Math, Player, Rng, Rules}

  setup do
    Clock.put_now(~U[2026-07-01 09:00:00Z])
    :ok
  end

  defp character(race_id, path, level \\ 1) do
    {player, _} = Player.initialize(%Player{}, Constants.race(race_id), path, "Hunter")
    Player.restore_fully(%{player | experience: Math.xp_for_level(level)})
  end

  defp fight(player, monster) do
    foe = Hunt.foe(Rules.monster(monster))
    Hunt.fight(Player.stats(player), player, Player.known_skills(player), foe)
  end

  # Every line its trainer has taught by its level, each at the highest it has reached.
  defp trained(race_id, path, level) do
    player = character(race_id, path, level)

    skills =
      for lesson <- Rules.lessons(Rules.set(race_id, path).name),
          lesson.learn_at <= level,
          reduce: player.skills,
          do: (known -> Map.update(known, lesson.skill, lesson.level, &max(&1, lesson.level)))

    Player.restore_fully(%{player | skills: skills})
  end

  # A level 1 Human Fighter given the Power Strike 1 its trainer teaches at 5, so a skill's numbers
  # are watched against a level 1 character's.
  defp striker,
    do: Player.restore_fully(%{character(0, :fighter) | skills: %{"Power Strike" => 1}})

  defp foe(monster), do: Hunt.foe(Rules.monster(monster))

  # Something that never falls and never swings, so a skill can be watched for as long as it lasts.
  defp dummy(monster), do: %{Hunt.foe(Rules.monster(monster)) | hp: 1_000_000_000, atk_spd: 0}

  defp events(result, kind),
    do:
      for(
        {round, event} <- result.log,
        is_tuple(event),
        elem(event, 0) == kind,
        do: {round, event}
      )

  # Dice as a cycled list of integers scaled into [0, 1), as AGENTS.md has them generated.
  defp dice(ints) do
    {:ok, agent} = Agent.start_link(fn -> ints end)

    Rng.put_source(fn ->
      Agent.get_and_update(agent, fn [n | rest] -> {n / 1_000, rest ++ [n]} end)
    end)
  end

  describe "who is met" do
    test "a monster from 3 levels below the character up to its own, never above" do
      ladder = Rules.monsters_of(Rules.ground("obelisk-of-victory"))

      for value <- [0.0, 0.5, 0.9999] do
        Rng.put_source(fn -> value end)
        assert Hunt.draw(ladder, 6).level in 3..6
      end
    end

    test "or the nearest, past the top of the ladder" do
      ladder = Rules.monsters_of(Rules.ground("obelisk-of-victory"))
      Rng.put_source(fn -> 0.0 end)

      assert Hunt.draw(ladder, 40).name == "Blade Spider"
    end
  end

  describe "the rounds" do
    test "with every roll landing, a Human Fighter opens with Power Strike and finishes with blows" do
      # 0.0 lands every blow as a critical, at the spread's low end: 51, then 21.
      Rng.put_source(fn -> 0.0 end)
      fighter = striker()
      result = fight(fighter, "Young Keltir")

      assert result.foe == 0
      assert result.rounds == 2
      assert result.uses == 1
      assert result.critical
      assert result.mp == fighter.mp - 10
    end

    test "a Mystic casts while its spell is ready, and pays for each cast" do
      Rng.put_source(fn -> 0.9999 end)
      mystic = character(0, :mystic)
      result = fight(mystic, "Elder Keltir")

      assert result.uses >= 1
      assert result.mp == mystic.mp - 9 * result.uses
    end

    test "an Orc Mystic casts Life Drain as a heal, only below 85% of its HP" do
      Rng.put_source(fn -> 0.0 end)
      orc = trained(1, :mystic, 7)
      stats = Player.stats(orc)

      spells = fn result ->
        for {_, event} <- result.log,
            is_tuple(event) and elem(event, 0) in [:cast, :drain],
            do: elem(event, 1)
      end

      whole = Hunt.fight(stats, orc, Player.known_skills(orc), dummy("Kasha Wolf"))
      assert "Chill Flame" in spells.(whole)
      refute "Life Drain" in spells.(whole)

      hurt = %{orc | health: div(stats.max_hp * 80, 100)}
      drained = Hunt.fight(stats, hurt, Player.known_skills(orc), dummy("Kasha Wolf"))

      # What it mends is in the log, at most 80% of what it dealt, and is what the bar gained.
      [{round, {:drain, "Life Drain", dealt, _, healed}} | _] = events(drained, :drain)
      assert healed > 0 and healed <= trunc(dealt * 0.8)
      before = for {r, {:standing, hp, _}} <- drained.log, r == round - 1, do: hp
      after_ = for {r, {:standing, hp, _}} <- drained.log, r == round, do: hp
      assert after_ == Enum.map(before, &(&1 + healed))

      assert "Life Drain" in spells.(
               Hunt.fight(stats, hurt, Player.known_skills(orc), dummy("Kasha Wolf"))
             )
    end

    test "a burn takes the last HP, so an Orc Mystic's Chill Flame alone fells a keltir" do
      Rng.put_source(fn -> 0.9999 end)
      result = fight(character(1, :mystic), "Young Prairie Keltir")

      # Every blow misses at 0.9999, so only the burn hurts, and it finishes the keltir.
      assert result.foe == 0
      assert result.rounds < Hunt.max_rounds()

      # Nobody acts in the round the burn ends.
      last = for {round, event} <- result.log, round == result.rounds, do: event
      assert [{:burn, _}, {:standing, _, 0}] = last
    end

    test "and it is not cast again while its target still burns" do
      # Every blow misses at 0.9999 and the keltir cannot die, so only the casting shows.
      Rng.put_source(fn -> 0.9999 end)
      mystic = character(1, :mystic)
      skill = Rules.first_skill(1, :mystic)
      foe = %{Hunt.foe(Rules.monster("Elder Prairie Keltir")) | hp: 1_000_000_000}
      result = Hunt.fight(Player.stats(mystic), mystic, [skill], foe)

      # Begun at once, it takes hold as its cast ends; the burn runs nine rounds from there, and a
      # second may only start once it has gone out.
      assert [{1, {:begin, "Chill Flame"}} | _] = events(result, :begin)
      casts = for {round, {:cast, "Chill Flame", _, _}} <- result.log, do: round
      assert Enum.all?(tl(casts), &(&1 > hd(casts) + 9)), inspect(casts)
    end

    test "with every blow missing, Power Strike still lands, and alone fells a Young Keltir" do
      # 62 at the spread's top, the keltir's whole HP.
      Rng.put_source(fn -> 0.9999 end)
      result = fight(striker(), "Young Keltir")

      assert result.foe == 0
      assert result.uses == 1
      assert result.rounds == 1
    end

    test "without its weapon in hand a skill is never used" do
      Rng.put_source(fn -> 0.0 end)
      fighter = striker()
      bare = %{fighter | items: Enum.map(fighter.items, &%{&1 | equipped: false})}

      assert fight(bare, "Young Keltir").uses == 0
    end
  end

  describe "time" do
    # A character nothing can kill, against a monster nothing can kill, so only the monster's pace
    # shows over the whole thousand rounds.
    defp target do
      player = character(0, :fighter)
      stats = %{Player.stats(player) | accuracy: -1_000, max_hp: 1_000_000}
      {stats, %{health: 1_000_000, mp: 0}}
    end

    test "a monster's bow draws and reloads, shooting Atk. Spd. / 610 times a round" do
      Rng.put_source(fn -> 0.0 end)
      {stats, bars} = target()
      # A skill it can never pay for, so it only ever swings, and misses.
      skill = %{Rules.first_skill(0, :fighter) | mp: 1}
      foe = %{Hunt.foe(Rules.monster("Orc Archer")) | hp: 1_000_000_000}
      result = Hunt.fight(stats, bars, [skill], foe)

      shots = Enum.count(result.log, &match?({_, {:foe_blow, _, _, _}}, &1))
      assert shots == trunc(Hunt.max_rounds() * 249 / 610)
    end

    test "a spell takes its cast time, during which its caster does nothing else" do
      Rng.put_source(fn -> 0.0 end)
      {stats, bars} = target()
      skill = %{Rules.first_skill(0, :fighter) | mp: 1}
      eye = %{Hunt.foe(Rules.monster("Evil Eye")) | hp: 1_000_000_000}
      foe = %{eye | spells: [Rules.monster_spell("NPC Windstrike - Magic 1")]}
      result = Hunt.fight(stats, bars, [skill], foe)

      # Windstrike - Magic: 4 seconds a cast, so each lands in the third round of its cast and the
      # next begins three rounds after the last.
      begun = for {round, {:foe_begin, "NPC Windstrike - Magic 1"}} <- result.log, do: round
      landed = for {round, {:foe_cast, "NPC Windstrike - Magic 1", _}} <- result.log, do: round

      assert Enum.take(begun, 5) == [1, 4, 7, 10, 13]
      assert Enum.take(landed, 5) == [3, 6, 9, 12, 15]
    end
  end

  describe "what a character knows" do
    # Orders that heal in the fight alone, so nothing is cast before the pull.
    defp fight_only(player, share \\ 50), do: %{player | heal_pull_at: 0, heal_fight_at: share}

    test "a heal is cast below the ordered share while the spells rest, and not above it" do
      Rng.put_source(fn -> 0.0 end)
      mystic = trained(0, :mystic, 1)
      skills = Player.known_skills(mystic)
      stats = Player.stats(mystic)

      hurt = Hunt.fight(stats, fight_only(%{mystic | health: 10}), skills, dummy("Young Keltir"))
      [{first, _}, {second, _} | _] = for {r, {:begin, "Wind Strike"}} <- hurt.log, do: {r, nil}
      [{healed, _} | _] = for {r, {:begin, "Self Heal"}} <- hurt.log, do: {r, nil}
      [{_, heal} | _] = events(hurt, :heal)

      assert first == 1 and healed in first..second
      assert heal == {:heal, "Self Heal", Hunt.heal_amount(42, stats.m_atk)}

      whole = Hunt.fight(stats, fight_only(mystic), skills, dummy("Young Keltir"))
      assert events(whole, :heal) == []
    end

    test "the share is the player's: never, or below a higher one" do
      Rng.put_source(fn -> 0.0 end)
      mystic = trained(0, :mystic, 1)
      skills = Player.known_skills(mystic)
      stats = Player.stats(mystic)
      # Above half, below seven tenths.
      bars = %{mystic | health: div(stats.max_hp * 6, 10)}

      assert events(Hunt.fight(stats, fight_only(bars, 50), skills, dummy("Young Keltir")), :heal) ==
               []

      assert [_ | _] =
               events(
                 Hunt.fight(stats, fight_only(bars, 70), skills, dummy("Young Keltir")),
                 :heal
               )

      assert events(
               Hunt.fight(
                 stats,
                 fight_only(%{bars | health: 10}, 0),
                 skills,
                 dummy("Young Keltir")
               ),
               :heal
             ) == []
    end

    # Heals alone, reversed so the lesser comes first and only strength picks the other.
    defp heals(player),
      do: player |> Player.known_skills() |> Enum.filter(&(&1.kind == :heal)) |> Enum.reverse()

    test "in the fight, the strongest heal it can pay for, a lesser one when that costs too much" do
      Rng.put_source(fn -> 0.0 end)
      elf = trained(2, :mystic, 7)
      [self_heal, heal] = heals(elf)
      assert heal.power > self_heal.power and heal.mp > self_heal.mp
      stats = Player.stats(elf)

      rested =
        Hunt.fight(stats, fight_only(%{elf | health: 10}), heals(elf), dummy("Young Keltir"))

      assert [{_, {:heal, "Heal", _}} | _] = events(rested, :heal)

      short = fight_only(%{elf | health: 10, mp: heal.mp - 1})

      assert [{_, {:heal, "Self Heal", _}} | _] =
               events(Hunt.fight(stats, short, heals(elf), dummy("Young Keltir")), :heal)
    end

    test "an aura is raised before the pull, its cast waited out, and not at all while it is up" do
      Rng.put_source(fn -> 0.0 end)
      elf = trained(2, :fighter, 5)
      stats = Player.stats(elf)
      result = Hunt.fight(stats, elf, Player.known_skills(elf), dummy("Young Keltir"))
      aura = Rules.skill("Defense Aura", 1)

      assert {[{:aura, "Defense Aura"}], _} = result.before
      assert events(result, :aura) == [] and events(result, :begin) == []
      assert result.raised == ["Defense Aura"]
      assert result.ms >= result.rounds * Hunt.round_ms() + Hunt.cast_ms(aura, stats)

      up = Map.put(stats, :auras, ["Defense Aura"])
      again = Hunt.fight(up, elf, Player.known_skills(elf), dummy("Young Keltir"))
      assert events(again, :aura) == [] and again.raised == []
    end

    test "a toggle is lit once, and drains MP until it goes out" do
      Rng.put_source(fn -> 0.0 end)
      orc = character(1, :mystic)
      soul_cry = Rules.skill("Soul Cry", 1)
      result = Hunt.fight(Player.stats(orc), orc, [soul_cry], dummy("Young Keltir"))

      assert events(result, :toggle) == [{1, {:toggle, "Soul Cry"}}]
      assert result.mp < soul_cry.mp
    end

    test "a poison lands at its chance, and is laid again only once it wears off" do
      {stats, bars} = target()
      bars = %{bars | mp: 1_000_000}
      poison = Rules.skill("Curse: Poison", 1)

      Rng.put_source(fn -> 0.0 end)
      result = Hunt.fight(stats, bars, [poison], dummy("Young Keltir"))
      [{first, _}, {second, _} | _] = events(result, :curse)
      assert second - first >= round(poison.lasts / Hunt.round_ms())

      Rng.put_source(fn -> 0.9999 end)
      missed = Hunt.fight(stats, bars, [poison], dummy("Young Keltir"))
      assert [{_, {:curse, "Curse: Poison", false}} | _] = events(missed, :curse)
    end

    test "a poison never takes the last HP, nor is it laid on a monster at half its HP" do
      Rng.put_source(fn -> 0.0 end)
      {stats, bars} = target()
      # It never swings, so only the poison wounds.
      stats = %{stats | blows_per_round: 0}
      bars = %{bars | mp: 1_000_000}
      result = Hunt.fight(stats, bars, [Rules.skill("Curse: Poison", 1)], foe("Young Keltir"))

      assert result.foe == 1
      assert [_once] = events(result, :curse)
    end

    test "a shackled monster swings less" do
      Rng.put_source(fn -> 0.0 end)
      {stats, bars} = target()
      bars = %{bars | mp: 1_000_000}
      foe = %{Hunt.foe(Rules.monster("Young Keltir")) | hp: 1_000_000_000}
      swings = &length(events(&1, :foe_blow))

      shackled = Hunt.fight(stats, bars, [Rules.skill("Wind Shackle", 1)], foe)
      assert swings.(shackled) < swings.(Hunt.fight(stats, bars, [], foe))
    end

    test "weapon skills without their weapons are left out of the log, not named in it" do
      Rng.put_source(fn -> 0.0 end)
      bare = %{trained(0, :fighter, 5) | items: []}

      refute Enum.any?(fight(bare, "Young Keltir").log, &match?({0, _}, &1))
    end
  end

  describe "the opening" do
    # Too tough to fall, so the opening plays out whatever is cast at it.
    defp tough(monster), do: %{foe(monster) | hp: 1_000_000_000}

    defp on(result, event), do: for({round, ^event} <- result.log, do: round)
    defp first(result, kind), do: result |> events(kind) |> Enum.map(&elem(&1, 0)) |> List.first()

    # §20: rounds a monster runs to cover the gap at its run speed, 1⅔ seconds each.
    defp running(gap, run_spd), do: ceil(gap / (run_spd * Hunt.round_ms() / 1000))

    test "a Mystic pulls from its spell's reach, and a melee monster runs in before its first blow" do
      Rng.put_source(fn -> 0.0 end)
      mystic = trained(0, :mystic, 1)
      keltir = tough("Young Keltir")
      result = Hunt.fight(Player.stats(mystic), mystic, Player.known_skills(mystic), keltir)

      # It stands until the opening spell lands, then runs from there.
      runs = running(Rules.reach(:spell) - Rules.reach(:blow), keltir.run_spd)
      landed = first(result, :cast)
      assert first(result, :begin) == 1 and landed > 1
      assert on(result, :closing) == Enum.to_list(landed..(landed + runs - 1))
      assert first(result, :foe_blow) > landed + runs - 1
    end

    test "a melee character against a passive monster starts toe to toe" do
      Rng.put_source(fn -> 0.0 end)
      fighter = character(0, :fighter)
      result = Hunt.fight(Player.stats(fighter), fighter, [], tough("Young Keltir"))

      assert on(result, :closing) == []
      assert first(result, :foe_blow) == 2
    end

    test "a spell takes effect in the round its cast ends, and the monster is untouched till then" do
      Rng.put_source(fn -> 0.0 end)
      mystic = trained(0, :mystic, 1)
      stats = Player.stats(mystic)
      [wind] = Enum.filter(Player.known_skills(mystic), &(&1.name == "Wind Strike"))
      keltir = tough("Young Keltir")
      result = Hunt.fight(stats, mystic, [wind], keltir)

      ends = wind.cast * 333 / stats.cast_spd
      landed = trunc(ends / Hunt.round_ms()) + 1
      assert first(result, :cast) == landed

      untouched = for {r, {:standing, _, foe}} <- result.log, r < landed, do: foe
      assert untouched != [] and Enum.all?(untouched, &(&1 == keltir.hp))
    end

    test "a Mystic lights its toggle only once its blows reach, a Fighter at once" do
      Rng.put_source(fn -> 0.0 end)
      orc = trained(1, :mystic, 1)
      keltir = tough("Young Keltir")
      result = Hunt.fight(Player.stats(orc), orc, Player.known_skills(orc), keltir)
      [{lit, _}] = events(result, :toggle)
      assert lit > Enum.max(on(result, :closing))

      fighter = %{character(1, :fighter) | skills: %{"Soul Cry" => 1}}

      ahead =
        Hunt.fight(
          Player.stats(fighter),
          fighter,
          Player.known_skills(fighter),
          tough("Orc Fighter")
        )

      assert [{1, _}] = events(ahead, :toggle)
      assert 1 in on(ahead, :closing)
    end

    test "a Fighter that knows a spell still pulls with its weapon" do
      Rng.put_source(fn -> 0.0 end)
      fighter = %{character(3, :fighter, 15) | skills: %{"Drain Health" => 1}}

      result =
        Hunt.fight(
          Player.stats(fighter),
          fighter,
          Player.known_skills(fighter),
          tough("Young Keltir")
        )

      assert on(result, :closing) == []
    end

    test "an aggressive monster comes at the character from where it notices it, and acts first" do
      Rng.put_source(fn -> 0.0 end)
      mystic = trained(0, :mystic, 1)
      orc = tough("Orc Fighter")
      assert orc.aggressive?
      result = Hunt.fight(Player.stats(mystic), mystic, Player.known_skills(mystic), orc)

      runs = running(Rules.reach(:notice) - Rules.reach(:blow), orc.run_spd)
      assert on(result, :closing) == Enum.to_list(1..runs)
      assert [:closing, {:begin, _} | _] = for({1, event} <- result.log, do: event)
    end

    test "a melee character runs at an aggressive archer, which shoots as it comes" do
      Rng.put_source(fn -> 0.0 end)
      fighter = character(0, :fighter)
      stats = Player.stats(fighter)
      archer = tough("Skeleton Longbowman")
      assert archer.aggressive? and archer.bow?
      result = Hunt.fight(stats, fighter, [], archer)

      runs = running(Rules.reach(:notice) - Rules.reach(:blow), stats.run_spd)
      assert on(result, :advancing) == Enum.to_list(1..runs)
      assert on(result, :closing) == []
      assert first(result, :foe_blow) <= runs
    end

    test "and waits for an aggressive monster that comes to it" do
      Rng.put_source(fn -> 0.0 end)
      fighter = character(0, :fighter)
      orc = tough("Orc Fighter")
      result = Hunt.fight(Player.stats(fighter), fighter, [], orc)

      runs = running(Rules.reach(:notice) - Rules.reach(:blow), orc.run_spd)
      assert on(result, :closing) == Enum.to_list(1..runs)
      assert on(result, :advancing) == []
      assert on(result, :waiting) != []
    end

    test "a bow pulls from its own reach" do
      Rng.put_source(fn -> 0.0 end)
      elf = character(2, :fighter)
      assert Player.stats(elf).weapon.type == "bow"
      keltir = tough("Young Keltir")
      result = Hunt.fight(Player.stats(elf), elf, [], keltir)

      # The first round draws the bow, which the keltir does not notice; it runs from the first shot.
      runs = running(Rules.reach(:bow) - Rules.reach(:blow), keltir.run_spd)
      assert on(result, :readying) == [1] or hd(on(result, :readying)) == 1
      shot = first(result, :blow) || hd(on(result, :miss))
      assert on(result, :closing) == Enum.to_list(shot..(shot + runs - 1))
    end

    test "an archer runs only until its bow reaches" do
      Rng.put_source(fn -> 0.0 end)
      mystic = trained(0, :mystic, 1)
      archer = tough("Orc Archer")
      result = Hunt.fight(Player.stats(mystic), mystic, Player.known_skills(mystic), archer)

      runs = running(Rules.reach(:spell) - Rules.reach(:bow), archer.run_spd)
      landed = first(result, :cast)
      assert on(result, :closing) == Enum.to_list(landed..(landed + runs - 1))
    end

    test "a monster's spell that reaches is cast from where it stands" do
      Rng.put_source(fn -> 0.0 end)
      mystic = trained(0, :mystic, 1)

      result =
        Hunt.fight(
          Player.stats(mystic),
          mystic,
          Player.known_skills(mystic),
          tough("Stone Golem")
        )

      # It begins in the round the Mystic's spell lands, from where it stood, and runs in only
      # while its spell rests.
      landed = first(result, :cast)
      assert first(result, :foe_begin) == landed
      assert Enum.all?(on(result, :closing), &(&1 > landed))
    end

    test "and one that does not reach waits until the monster has run close enough" do
      Rng.put_source(fn -> 0.0 end)
      mystic = trained(0, :mystic, 1)
      burn = Rules.monster_spell("NPC Aura Burn - Magic 1")
      eye = %{tough("Evil Eye") | spells: [burn]}
      result = Hunt.fight(Player.stats(mystic), mystic, Player.known_skills(mystic), eye)

      assert first(result, :foe_cast) > running(Rules.reach(:spell) - burn.range, eye.run_spd)
    end

    test "an Evil Eye burns a character beside it, and drains one at a distance first" do
      Rng.put_source(fn -> 0.0 end)
      fighter = striker()
      result = fight(fighter, "Evil Eye Watcher")

      spells =
        for {_, event} <- result.log,
            is_tuple(event) and elem(event, 0) in [:foe_cast, :foe_drain],
            uniq: true,
            do: elem(event, 1)

      assert spells == ["NPC Aura Burn - Magic 1"]

      mystic = trained(0, :mystic, 1)
      eye = tough("Evil Eye Watcher")
      result = Hunt.fight(Player.stats(mystic), mystic, Player.known_skills(mystic), eye)
      assert [{_, {:foe_begin, "NPC HP Drain - Magic 1"}} | _] = events(result, :foe_begin)

      # What its drain mends is in the log, and is what its HP gained, never past its most.
      drains = events(result, :foe_drain)
      assert Enum.any?(drains, &match?({_, {:foe_drain, _, _, healed}} when healed > 0, &1))

      for {round, {:foe_drain, _, lost, healed}} <- drains do
        [was] = for {r, {:standing, _, foe}} <- result.log, r == round - 1, do: foe
        [now] = for {r, {:standing, _, foe}} <- result.log, r == round, do: foe
        assert healed <= trunc(lost * 0.2) and now - was <= healed
      end
    end

    test "an Ice-Bolted monster runs 30% slower" do
      Rng.put_source(fn -> 0.0 end)
      mystic = trained(0, :mystic, 7)
      stats = Player.stats(mystic)
      keltir = tough("Young Keltir")
      bolt = Enum.filter(Player.known_skills(mystic), &(&1.name == "Ice Bolt"))
      wind = Enum.filter(Player.known_skills(mystic), &(&1.name == "Wind Strike"))
      gap = Rules.reach(:spell) - Rules.reach(:blow)

      assert length(on(Hunt.fight(stats, mystic, wind, keltir), :closing)) ==
               running(gap, keltir.run_spd)

      assert length(on(Hunt.fight(stats, mystic, bolt, keltir), :closing)) ==
               running(gap, keltir.run_spd * 0.7)
    end

    test "a character whose blows cannot reach yet waits, then fights where the monster stands" do
      Rng.put_source(fn -> 0.0 end)
      mystic = trained(0, :mystic, 1)
      [wind] = Enum.filter(Player.known_skills(mystic), &(&1.name == "Wind Strike"))

      # One spell's MP, and a monster that crawls, so the Mystic outlasts its MP before it arrives.
      zombie = tough("Tainted Zombie")
      result = Hunt.fight(Player.stats(mystic), %{mystic | mp: wind.mp}, [wind], zombie)

      waits = on(result, :waiting)
      closes = on(result, :closing)
      assert waits != [] and Enum.max(waits) <= Enum.max(closes)
      swings = on(result, :miss) ++ for({r, {:blow, _, _}} <- result.log, do: r)
      assert Enum.min(swings) > Enum.max(closes)
    end
  end

  describe "before the pull" do
    # Down with the first spell, and never swinging back, so only the heals move HP.
    defp frail(monster), do: %{foe(monster) | hp: 1, atk_spd: 0}

    test "it heals while below its ordered share, the strongest it can pay for, and stops above it" do
      Rng.put_source(fn -> 0.0 end)
      elf = trained(2, :mystic, 7)
      stats = Player.stats(elf)

      result =
        Hunt.fight(stats, %{elf | health: 1}, Player.known_skills(elf), frail("Young Keltir"))

      assert {[{:heal, "Heal", _} | _] = heals, pulled} = result.before
      assert pulled == 1 + Enum.sum(Enum.map(heals, &elem(&1, 2)))
      assert pulled * 100 >= stats.max_hp * elf.heal_pull_at
      assert (pulled - elem(List.last(heals), 2)) * 100 < stats.max_hp * elf.heal_pull_at
      assert [{1, {:begin, _}} | _] = events(result, :begin)
    end

    test "not at all above its share, nor when its order is never" do
      Rng.put_source(fn -> 0.0 end)
      elf = trained(2, :mystic, 7)
      stats = Player.stats(elf)
      skills = Player.known_skills(elf)
      above = div(stats.max_hp * (elf.heal_pull_at + 10), 100)

      assert Hunt.fight(stats, %{elf | health: above}, skills, frail("Young Keltir")).before ==
               {[], above}

      never = %{elf | health: 1, heal_pull_at: 0}
      assert Hunt.fight(stats, never, skills, frail("Young Keltir")).before == {[], 1}
    end

    test "until it cannot pay for another" do
      Rng.put_source(fn -> 0.0 end)
      elf = trained(2, :mystic, 7)
      [_self_heal, heal] = heals(elf)

      result =
        Hunt.fight(
          Player.stats(elf),
          %{elf | health: 1, mp: heal.mp + 5},
          Player.known_skills(elf),
          frail("Young Keltir")
        )

      assert {[{:heal, "Heal", _}], _} = result.before
      assert result.mp == 5
    end

    test "a heal cast before the pull is still resting when the fight begins" do
      Rng.put_source(fn -> 0.0 end)
      elf = trained(2, :mystic, 7)
      stats = Player.stats(elf)
      # Heal alone, to half before the pull, and in the fight below eight tenths.
      heal = Enum.filter(heals(elf), &(&1.name == "Heal"))
      bars = %{elf | health: 1, heal_fight_at: 80}

      pulled = Hunt.fight(stats, bars, heal, dummy("Young Keltir"))
      assert {[_ | _], _} = pulled.before
      assert [{round, _} | _] = events(pulled, :begin)
      assert round > 1

      fresh = Hunt.fight(stats, %{bars | heal_pull_at: 0}, heal, dummy("Young Keltir"))
      assert [{1, _} | _] = events(fresh, :begin)
    end

    test "and none once the monster is down, the fight's cost left for the rest" do
      Rng.put_source(fn -> 0.0 end)
      elf = trained(2, :mystic, 7)
      # Tough enough to land its blows, never a critical.
      foe = %{foe("Kaboo Orc Fighter") | hp: 1_200, critical: 0}

      result = Hunt.fight(Player.stats(elf), elf, Player.known_skills(elf), foe)
      assert result.foe == 0
      [{:standing, hp, 0} | _] = for {_, {:standing, _, _} = e} <- Enum.reverse(result.log), do: e
      assert result.health == hp and hp < Player.stats(elf).max_hp
    end

    test "the orders are a share the rules offer, given only with a heal, and kept with the character" do
      fighter = character(0, :fighter)
      assert {_, {:error, :no_heal, _}} = Actions.heal_at(fighter, :pull, 30)

      elf = trained(2, :mystic, 7)
      {elf, {:ok, _}} = Actions.heal_at(elf, :pull, 30)
      {elf, {:ok, _}} = Actions.heal_at(elf, :fight, 0)
      assert {elf.heal_pull_at, elf.heal_fight_at} == {30, 0}
      assert {_, {:error, :no_share, _}} = Actions.heal_at(elf, :fight, 40)

      stored = elf |> Serde.to_map() |> JSON.encode!() |> JSON.decode!()
      assert %{heal_pull_at: 30, heal_fight_at: 0} = Serde.from_map(stored)
      assert Serde.from_map(Map.delete(stored, "heal_pull_at")).heal_pull_at == 70
      assert Serde.from_map(Map.put(stored, "heal_fight_at", 40)).heal_fight_at == 0
    end

    test "and the time spent on heals is counted" do
      Rng.put_source(fn -> 0.0 end)
      elf = trained(2, :mystic, 7)
      skills = Player.known_skills(elf)
      stats = Player.stats(elf)

      whole = Hunt.fight(stats, elf, skills, frail("Young Keltir"))
      assert whole.ms == whole.rounds * Hunt.round_ms()

      hurt = Hunt.fight(stats, %{elf | health: 1}, skills, frail("Young Keltir"))
      {[{:heal, first, _} | _], _} = hurt.before
      heal = Enum.find(skills, &(&1.name == first))
      assert hurt.ms >= hurt.rounds * Hunt.round_ms() + heal.cast * 333 / stats.cast_spd
    end
  end

  describe "the reward" do
    test "is whole up to 5 levels above, and 5/6 a level past it, at the server's rates" do
      assert Hunt.reward(:exp, 100, 6, 1) == 500
      assert Hunt.reward(:exp, 100, 7, 1) == 416
      assert Hunt.reward(:sp, 100, 8, 1) == 347
    end

    test "Adena only at its chance, and between its least and most" do
      keltir = Rules.monster("Young Keltir")
      Rng.put_source(fn -> 0.0 end)
      assert Hunt.adena(keltir) == keltir.adena_min * 20
      Rng.put_source(fn -> 0.9999 end)
      assert Hunt.adena(keltir) == 0
    end
  end

  defp sets, do: for(race <- 0..3, path <- [:fighter, :mystic], do: {race, path})

  property "a fight always ends: someone falls, or the rounds run out, and no bar goes below 0" do
    check all {race, path} <- member_of(sets()),
              level <- integer(1..20),
              ground <- member_of(Rules.grounds()),
              rolls <- list_of(integer(0..999), min_length: 1, max_length: 40),
              max_runs: 200 do
      dice(rolls)
      player = character(race, path, level)
      monster = Hunt.draw(Rules.monsters_of(ground), level)
      result = fight(trained(race, path, level), monster.name)

      assert result.health == 0 or result.foe == 0 or result.rounds == Hunt.max_rounds()
      assert result.health >= 0 and result.foe >= 0 and result.mp >= 0
      assert result.health <= Player.stats(player).max_hp
    end
  end
end
