defmodule MiniLineage.Game.HuntTest do
  @moduledoc """
  Rules §20's fight, pure: who is met, how the rounds go, and what a kill pays. Dice are pinned or
  generated, never rolled freely, so nothing here asserts on chance.
  """
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias MiniLineage.Game.{Clock, Constants, Hunt, Math, Player, Rng, Rules}

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
      result = fight(character(0, :fighter), "Young Keltir")

      assert result.foe == 0
      assert result.rounds == 2
      assert result.uses == 1
      assert result.critical
      assert result.mp == character(0, :fighter).mp - 10
    end

    test "a Mystic casts while its spell is ready, and pays for each cast" do
      Rng.put_source(fn -> 0.9999 end)
      mystic = character(0, :mystic)
      result = fight(mystic, "Elder Keltir")

      assert result.uses >= 1
      assert result.mp == mystic.mp - 9 * result.uses
    end

    test "a burn never takes the last HP, so an Orc Mystic needs its fists to finish" do
      Rng.put_source(fn -> 0.9999 end)
      result = fight(character(1, :mystic), "Young Prairie Keltir")

      # Every blow misses at 0.9999, so only the burn hurts, and it stops at 1.
      assert result.foe == 1
      assert result.rounds == Hunt.max_rounds()
    end

    test "and it is not cast again while its target still burns" do
      # Every blow misses at 0.9999 and the keltir cannot die, so only the casting shows.
      Rng.put_source(fn -> 0.9999 end)
      mystic = character(1, :mystic)
      skill = Rules.first_skill(1, :mystic)
      foe = %{Hunt.foe(Rules.monster("Elder Prairie Keltir")) | hp: 1_000_000_000}
      result = Hunt.fight(Player.stats(mystic), mystic, [skill], foe)

      # The first burn runs nine rounds; a second may only start once it has gone out.
      casts = for {round, {:cast, "Chill Flame", _, _}} <- result.log, do: round
      assert hd(casts) == 1
      assert Enum.all?(tl(casts), &(&1 > 10)), inspect(casts)
    end

    test "with every blow missing, Power Strike still lands, and alone fells a Young Keltir" do
      # 62 at the spread's top, the keltir's whole HP.
      Rng.put_source(fn -> 0.9999 end)
      result = fight(character(0, :fighter), "Young Keltir")

      assert result.foe == 0
      assert result.uses == 1
      assert result.rounds == 1
    end

    test "without its weapon in hand a skill is never used" do
      Rng.put_source(fn -> 0.0 end)
      fighter = character(0, :fighter)
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
      foe = %{Hunt.foe(Rules.monster("Evil Eye")) | hp: 1_000_000_000}
      result = Hunt.fight(stats, bars, [skill], foe)

      # Windstrike - Magic: 4 seconds a cast, so the next comes three rounds after the last.
      casts =
        for {round, {:foe_cast, "NPC Windstrike - Magic 1", _}} <- result.log, do: round

      assert Enum.take(casts, 5) == [1, 4, 7, 10, 13]
    end
  end

  describe "what a character knows" do
    test "a heal is cast below half HP while the spells rest, and not above it" do
      Rng.put_source(fn -> 0.0 end)
      mystic = character(0, :mystic)
      skills = Player.known_skills(mystic)
      stats = Player.stats(mystic)

      hurt = Hunt.fight(stats, %{mystic | health: 10}, skills, dummy("Young Keltir"))
      [{first, _}, {second, _} | _] = events(hurt, :cast)
      [{healed, heal} | _] = events(hurt, :heal)

      assert first == 1 and healed in first..second
      assert heal == {:heal, "Self Heal", Hunt.heal_amount(42, stats.m_atk)}

      whole = Hunt.fight(stats, mystic, skills, dummy("Young Keltir"))
      assert events(whole, :heal) == []
    end

    test "an aura is raised once, and not at all while it is still up" do
      Rng.put_source(fn -> 0.0 end)
      elf = trained(2, :fighter, 5)
      stats = Player.stats(elf)
      result = Hunt.fight(stats, elf, Player.known_skills(elf), dummy("Young Keltir"))

      assert events(result, :aura) == [{1, {:aura, "Defense Aura"}}]
      assert result.raised == ["Defense Aura"]

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
      assert {1, {:curse, "Curse: Poison", false}} in missed.log
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
