defmodule MiniLineage.Game.NarrativeTest do
  @moduledoc """
  The prose the player reads. `Format.fill_template/2` leaves an unrecognised `{placeholder}` in
  place rather than raising, so a typo ships verbatim; these drive every race and path, and fail on
  any brace that survives.
  """
  use ExUnit.Case, async: true

  alias MiniLineage.Game.{
    Actions,
    Constants,
    Hunt,
    Math,
    Narrative,
    Narratives,
    Player,
    Rng,
    Rules
  }

  @races 0..3

  defp unrendered(text), do: Regex.scan(~r/\{[^}]*\}/, text) |> List.flatten()

  # A level 10 swordsman with a shield, unless a test arms it otherwise.
  @weapon %{
    level: 10,
    max_hp: 100,
    hp: 100,
    weapon: Rules.item("Long Sword"),
    shield: Rules.item("Round Shield")
  }

  # A fight log as its owner reads it, each entry voiced and its markup stripped; `kind` is no prose.
  defp read(foe, log, before \\ {[], 100}) do
    foe
    |> Narrative.build_fight_log(Rules.ground("obelisk-of-victory"), log, @weapon, before)
    |> Enum.map(fn entry ->
      Map.new(entry, fn
        {:kind, kind} -> {:kind, kind}
        {key, html} -> {key, html |> Narrative.alert() |> plain()}
      end)
    end)
  end

  defp plain(html), do: html |> String.replace(~r/<[^>]+>/, "") |> String.replace("&bull;", "•")

  # A fight the game plays for a set at a level, its kit or the best its village sells, and its
  # rounds' lines as their owner reads them.
  defp fight_lines(race_id, path, twinked?, level, ground, monster, mp, hp) do
    {fresh, _flash} = Player.initialize(%Player{}, Constants.race(race_id), path, "Hunter")
    potions = [Player.new_item("Lesser Healing Potion", false, 5)]
    kit = %{fresh | items: fresh.items ++ potions}
    dressed = if twinked?, do: elem(Actions.dev_twink(kit), 0), else: kit

    skills =
      for lesson <- Rules.lessons(Rules.set(race_id, path).name),
          lesson.learn_at <= level,
          reduce: fresh.skills,
          do: (known -> Map.update(known, lesson.skill, lesson.level, &max(&1, lesson.level)))

    whole =
      Player.restore_fully(%{dressed | experience: Math.xp_for_level(level), skills: skills})

    player = %{whole | mp: trunc(whole.mp * mp), health: max(trunc(whole.health * hp), 1)}
    stats = Player.stats(player)
    foe = Hunt.foe(monster)

    bars = %{
      health: player.health,
      mp: player.mp,
      potions: Player.potions(player),
      potion_at: player.potion_at,
      heal_pull_at: 0,
      path: player.path,
      heal_fight_at: 50
    }

    result = Hunt.fight(stats, bars, Player.fighting_skills(player), foe)

    weapon = %{
      level: Player.level(player),
      max_hp: stats.max_hp,
      hp: player.health,
      weapon: stats.weapon,
      shield: stats.shield
    }

    for entry <- Narrative.build_fight_log(foe, ground, result.log, weapon, result.before),
        String.starts_with?(entry.head, "Round"),
        do: plain(Narrative.alert(entry.line))
  end

  describe "the opening flash" do
    test "names the class and the starting town, and renders cleanly" do
      for race_id <- @races, path <- [:fighter, :mystic] do
        race = Constants.race(race_id)

        {_player, flash} = Player.initialize(%Player{}, race, path, "Hero")

        assert unrendered(flash.text) == [], "race #{race_id}: #{inspect(unrendered(flash.text))}"
        assert flash.text =~ Rules.set(race_id, path).name
        assert flash.text =~ Rules.town(Rules.hometown(race_id)).name
      end
    end
  end

  describe "the fight log" do
    test "colours the monster's level by where it stands against the character's (rules §20)" do
      ground = Rules.ground("obelisk-of-victory")

      for {name, level, class} <- [
            {"Orc Fighter", 8, "level perilous"},
            {"Orc Fighter", 9, "level above"},
            {"Orc Fighter", 10, "level"},
            {"Orc Fighter", 11, "level below"},
            {"Orc Fighter", 12, "level outgrown"}
          ] do
        [met] =
          Rules.monster(name)
          |> Narrative.build_fight_log(ground, [], %{@weapon | level: level}, {[], 80})

        assert met.line =~ ~s(<span class="#{class}">Level 10</span>), class
      end
    end

    test "an aggressive monster comes at the character, a passive one is met" do
      ground = Rules.ground("obelisk-of-victory")

      [noticed] =
        Narrative.build_fight_log(Rules.monster("Orc Fighter"), ground, [], @weapon, {[], 80})

      [met] =
        Rules.monster("Young Keltir")
        |> Narrative.build_fight_log(ground, [], %{@weapon | level: 1}, {[], 80})

      assert Narrative.alert(noticed.line) =~
               ~r/^An Orc Fighter, <span class="level">Level 10<\/span>, notices you on the .* and comes at you\.$/

      assert noticed.head == "Ambush"
      assert noticed.kind == "ambush"
      # A level is gold whole and named as one, "Level 1", as every page writes it.
      assert Narrative.alert(met.line) =~
               ~r/^You meet a Young Keltir, <span class="level">Level 1<\/span>,/

      assert met.head == "Encounter"
      assert met.kind == "encounter"
      # Where both stand as they meet: the monster whole, the character as it went in.
      assert plain(Narrative.alert(met.standing)) == "Foe 100% • You 100%"
      assert unrendered(Narrative.voiced(noticed.line, false)) == []

      assert plain(Narrative.voiced(noticed.standing, false)) ==
               "Foe 100% • They 100%"
    end

    test "tells a side's swings in one round as one clause, its motion first, each in order" do
      foe = Rules.monster("Vaiss Orc")

      log = [
        {1, {:blow, 10, false, 0}},
        {1, {:blow, 9, false, 0}},
        {2, {:blow, 65, true, 0}},
        {2, :miss},
        {2, {:foe_blow, 12, false, nil, 0}},
        {2, :foe_miss},
        {3, {:foe_blow, 8, false, :caught, 0}},
        {3, {:foe_blow, 1, false, :perfect, 0}},
        {3, {:foe_blow, 30, true, nil, 0}},
        {4, {:foe_drain, "NPC HP Drain - Magic 1", 20, 4, 0, 0}},
        {5, {:blow, 11, false, 0}},
        {5, {:foe_blow, 7, false, nil, 0}},
        {6, {:blow, 40, true, 0}},
        {6, :foe_miss}
      ]

      log = log ++ for(round <- 1..6, do: {round, {:standing, 90, 20}})

      [_met | rounds] = read(foe, log)
      [one, two, three, four, five, six] = rounds

      assert one == %{
               head: "Round 1 • 0.0s",
               kind: nil,
               standing: "Foe #{div(20 * 100, foe.hp)}% • You 90%",
               line: "You swing your 🗡️ Long Sword twice and hit for 10 and 9 damage."
             }

      assert two.head == "Round 2 • 1.7s"

      assert two.line ==
               "You swing your 🗡️ Long Sword twice: a critical hit of 65 damage and a miss. The Vaiss Orc swings twice: a hit of 12 damage and a miss."

      assert three.line ==
               "The Vaiss Orc swings 3 times: a hit of 8 damage on your 🛡️ Round Shield, a glancing blow of 1 damage off your 🛡️ Round Shield and a critical hit of 30 damage."

      assert four.line == "The Vaiss Orc casts 🦟 HP Drain on you for 20 damage and mends 4 HP."

      assert five == %{
               five
               | head: "Round 5 • 6.7s",
                 line:
                   "You swing your 🗡️ Long Sword and hit for 11 damage. The Vaiss Orc swings and hits you for 7 damage."
             }

      assert six.line ==
               "You swing your 🗡️ Long Sword and land a critical hit for 40 damage. The Vaiss Orc swings and misses."

      for entry <- rounds,
          text <- [entry.head, entry.standing, entry.line],
          do: assert(unrendered(text) == [], text)
    end

    test "writes a hit that fells, or a mend that fills, at what it was worth, the rest in brackets" do
      foe = Rules.monster("Vaiss Orc")

      log = [
        {1, {:blow, 10, false, 0}},
        {1, {:blow, 5, false, 14}},
        {2, {:foe_blow, 1, false, nil, 19}},
        {3, {:drain, "Life Drain", 6, false, 4, 14, 2}},
        {4, {:potion, "Lesser Healing Potion", 81, 31}},
        {5, {:blow, 9, false, 0}},
        {5, {:blow, 5, true, 15}},
        {6, {:foe_drain, "NPC HP Drain - Magic 1", 1, 0, 19, 0}},
        {7, {:burn, "Chill Flame", 3, 2}},
        {8, {:drain, "Vampiric Touch", 248, false, 0, 0, 99}},
        {9, {:foe_drain, "NPC HP Drain - Magic 1", 20, 0, 0, 4}}
      ]

      log = log ++ for(round <- 1..9, do: {round, {:standing, 90, 20}})

      [_met | rounds] = read(foe, log)

      assert Enum.map(rounds, & &1.line) == [
               "You swing your 🗡️ Long Sword twice and hit for 10 and 19 damage (14 overkill).",
               "The Vaiss Orc swings and hits you for 20 damage (19 overkill).",
               "You cast 🖤 Life Drain for 20 damage (14 overkill) and mend 6 HP (2 overheal).",
               "You drink a 🧪 Lesser Healing Potion and mend 112 HP (31 overheal).",
               "You swing your 🗡️ Long Sword twice: a hit of 9 damage and a critical hit of 20 damage (15 overkill).",
               "The Vaiss Orc casts 🦟 HP Drain on you for 20 damage (19 overkill).",
               "Your 🔥 Chill Flame burns the Vaiss Orc for 5 damage (2 overkill).",
               "You cast 🦇 Vampiric Touch for 248 damage and mend 99 HP (99 overheal).",
               "The Vaiss Orc casts 🦟 HP Drain on you for 20 damage and mends 4 HP (4 overheal)."
             ]
    end

    test "writes a critical hit in its orange whichever side lands it" do
      foe = Rules.monster("Vaiss Orc")

      log = [
        {1, {:blow, 40, true, 0}},
        {1, {:foe_blow, 30, true, nil, 0}},
        {2, {:foe_blow, 25, true, nil, 0}},
        {2, :foe_miss},
        {1, {:standing, 70, 20}},
        {2, {:standing, 45, 20}}
      ]

      lines =
        foe
        |> Narrative.build_fight_log(Rules.ground("obelisk-of-victory"), log, @weapon, {[], 100})
        |> Enum.map(&Narrative.alert(&1.line))

      for amount <- [40, 30, 25],
          do: assert(Enum.any?(lines, &(&1 =~ ~s(<span class="crit">#{amount} damage</span>))))
    end

    test "says a cast or a run once as it begins, and leaves out a round with nothing new" do
      foe = Rules.monster("Goblin Scout")

      log = [
        {1, {:begin, "Wind Strike"}},
        {2, :casting},
        {3, {:cast, "Wind Strike", 112, false, 0}},
        {3, :closing},
        {4, :waiting},
        {4, :closing},
        {5, {:blow, 9, false, 0}},
        {5, :closing},
        {6, {:begin, "Ice Bolt"}},
        {7, :casting},
        {7, {:foe_blow, 5, false, nil, 0}},
        {8, :casting}
      ]

      log = log ++ for(round <- 1..8, do: {round, {:standing, 90, 20}})

      assert [_met, one, three, five, _six, seven] = read(foe, log)
      assert {one.head, one.line} == {"Round 1 • 0.0s", "You begin casting 🌪️ Wind Strike."}

      assert {three.head, three.line} ==
               {"Round 3 • 3.3s",
                "You cast 🌪️ Wind Strike for 112 damage. The Goblin Scout runs at you."}

      assert {five.head, five.line} ==
               {"Round 5 • 6.7s", "You swing your 🗡️ Long Sword and hit for 9 damage."}

      # A round with something else in it says why the character did nothing.
      assert {seven.head, seven.line} ==
               {"Round 7 • 10.0s",
                "As you cast, the Goblin Scout swings and hits you for 5 damage."}
    end

    test "says once that the character lacks the MP for its spell, and how a lone miss was made" do
      foe = Rules.monster("Mist Terror")

      log = [
        {4, {:no_mp, "Wind Strike"}},
        {4, :miss},
        {4, {:standing, 89, 51}},
        {5, :miss},
        {5, {:foe_blow, 22, false, nil, 0}},
        {5, {:standing, 82, 51}}
      ]

      [_met, four, five] = read(foe, log)

      assert four.line ==
               "You lack the MP for 🌪️ Wind Strike, and you swing your 🗡️ Long Sword and miss."

      assert five.line ==
               "You swing your 🗡️ Long Sword and miss. The Mist Terror swings and hits you for 22 damage."

      [_met, theirs, _five] =
        Narrative.build_fight_log(foe, Rules.ground("elven-fortress"), log, @weapon, {[], 100})

      assert plain(Narrative.voiced(theirs.line, false)) ==
               "They lack the MP for 🌪️ Wind Strike, and they swing their 🗡️ Long Sword and miss."
    end

    test "every attack names its motion and its weapon: a bow shoots, fists punch, any other swings" do
      archer = Rules.monster("Orc Archer")
      assert archer.bow?

      log = [
        {1, {:blow, 30, false, 0}},
        {1, {:foe_blow, 12, false, nil, 0}},
        {2, :miss},
        {2, :readying},
        {2, {:foe_blow, 9, false, :caught, 0}},
        {3, {:skill, "Mortal Blow", 0, 0}}
      ]

      log = log ++ for(round <- 1..3, do: {round, {:standing, 90, 20}})

      told = fn weapon ->
        archer
        |> Narrative.build_fight_log(
          Rules.ground("obelisk-of-victory"),
          log,
          %{@weapon | weapon: weapon && Rules.item(weapon)},
          {[], 100}
        )
        |> tl()
        |> Enum.map(&plain(Narrative.alert(&1.line)))
      end

      assert told.("Cestus") == [
               "You punch with your 🥊 Cestus and hit for 30 damage. The Orc Archer shoots and hits you for 12 damage.",
               "You punch with your 🥊 Cestus and miss, and you close in for the next blow. The Orc Archer shoots and hits your 🛡️ Round Shield for 9 damage.",
               "You use 🎯 Mortal Blow and miss."
             ]

      assert [first, second, _] = told.("Forest Bow")
      assert first =~ "You shoot your 🏹 Forest Bow and hit for 30 damage."
      assert second =~ "You shoot your 🏹 Forest Bow and miss, and you draw your 🏹 Forest Bow."

      assert [dagger, _, _] = told.("Throwing Knife")
      assert dagger =~ "You swing your 🔪 Throwing Knife and hit for 30 damage."

      # Bare hands punch, with nothing to name.
      assert [bare, _, _] = told.(nil)
      assert bare =~ "You punch and hit for 30 damage."
    end

    test "tells each side in a sentence of its own, in the order they acted" do
      foe = Rules.monster("Orc Fighter")

      log = [
        {1, {:potion, "Lesser Healing Potion", 112, 0}},
        {1, :closing},
        {1, {:begin, "Wind Strike"}},
        {2, :casting},
        {2, {:burn, "Chill Flame", 33, 0}},
        {2, {:foe_blow, 10, false, nil, 0}}
      ]

      log = log ++ for(round <- 1..2, do: {round, {:standing, 90, 20}})

      assert [_met, one, two] = read(foe, log)

      assert one.line ==
               "You drink a 🧪 Lesser Healing Potion and mend 112 HP. The Orc Fighter runs at you. You begin casting 🌪️ Wind Strike."

      assert two.line ==
               "As you cast, your 🔥 Chill Flame burns the Orc Fighter for 33 damage. The Orc Fighter swings and hits you for 10 damage."
    end

    # Rules §20: whatever a fight holds, every round reads one sentence a side at a time, each with
    # one ", and" at most, and none of the wording the log no longer uses.
    test "every fight any set plays reads one side a sentence, in the log's own words" do
      :rand.seed(:exsss, {20, 26, 10})
      Rng.put_source(fn -> :rand.uniform() end)

      lines =
        for race_id <- 0..3,
            path <- [:fighter, :mystic],
            twinked? <- [false, true],
            level <- [1, 7, 13, 20],
            ground = Rules.ground_of(Rules.hometown(race_id)),
            monster <-
              ground |> Rules.monsters_of() |> Enum.filter(&(&1.level <= level)) |> Enum.take(-3),
            {mp, hp} <- [{1.0, 1.0}, {0.0, 0.4}] do
          fight_lines(race_id, path, twinked?, level, ground, monster, mp, hp)
        end
        |> List.flatten()

      assert length(lines) > 1_000

      for line <- lines do
        sentences = line |> String.trim_trailing(".") |> String.split(". ")
        sides = Enum.map(sentences, &(String.replace(&1, ~r/^As you cast, /, "") =~ ~r/^The /))

        assert unrendered(line) == [], line
        assert sides == Enum.dedup(sides), line
        assert Enum.all?(sentences, &(length(String.split(&1, ", and ")) <= 2)), line
        refute line =~ ~r/\btick\b|strikes true|fails to land|turns .* aside|you hit for/i, line
        # Every attack names its weapon, and every skill or item wears its emoji.
        refute line =~ ~r/(You|you) (swing|shoot) and/, line
        refute line =~ ~r/(cast|use|raise your|drink a|casting) [A-Z]/, line
      end
    end

    test "a side whose every swing missed misses so many times" do
      foe = Rules.monster("Vaiss Orc")

      log = [
        {1, :miss},
        {1, :miss},
        {1, :foe_miss},
        {1, :foe_miss},
        {1, :foe_miss},
        {1, {:standing, 90, 20}}
      ]

      [_met, one] = read(foe, log)

      assert one.line ==
               "You swing your 🗡️ Long Sword twice and miss both times. The Vaiss Orc swings 3 times and misses every time."
    end

    test "writes every event a skill makes, open-voiced and with no brace left" do
      foe = Rules.monster("Young Keltir")
      ground = Rules.ground("obelisk-of-victory")

      log = [
        {1, {:heal, "Self Heal", 42, 0}},
        {1, {:drain, "Life Drain", 14, false, 11, 0, 0}},
        {2, {:drain, "Vampiric Touch", 30, true, 12, 0, 0}},
        {2, {:drain, "Life Drain", 9, false, 0, 0, 0}},
        {2, {:toggle, "Soul Cry"}},
        {3, {:curse, "Curse: Poison", true}},
        {3, {:poison, "Curse: Poison", 8, 0}},
        {4, {:curse, "Wind Shackle", false}},
        {4, {:potion, "Lesser Healing Potion", 112, 0}},
        {4, :waiting},
        {4, :closing},
        {4, :advancing},
        {4, {:begin, "Wind Strike"}},
        {4, {:foe_begin, "NPC Windstrike - Magic 1"}},
        {5, {:ignite, "Chill Flame"}},
        {6, {:burn, "Chill Flame", 33, 0}}
      ]

      # Every round ends on where both stand, as the engine writes it.
      log = log ++ for(round <- 1..6, do: {round, {:standing, 90, 20}})

      lines =
        foe
        |> Narrative.build_fight_log(
          ground,
          log,
          @weapon,
          {[{:aura, "Defense Aura"}, {:heal, "Heal", 70, 0}, {:heal, "Heal", 45, 0}], 60}
        )
        |> Enum.flat_map(&[&1.standing, &1.line])
        |> Enum.map(&Narrative.alert/1)

      for line <- lines do
        assert unrendered(line) == [], line
        refute line =~ "—", line
      end

      text = lines |> Enum.map(&plain/1) |> Enum.join("\n")
      assert text =~ "cast 💚 Self Heal and mend 42 HP"
      assert text =~ "cast 🖤 Life Drain for 14 damage and mend 11 HP"
      assert text =~ "cast 🦇 Vampiric Touch and land a critical hit for 30 damage, mending 12 HP"
      assert text =~ "cast 🖤 Life Drain for 9 damage,"
      assert text =~ "You raise your 🧱 Defense Aura"
      assert text =~ "you let out a 📢 Soul Cry to make your blows heavier"
      assert text =~ "lay ☠️ Curse: Poison on the Young Keltir"
      assert text =~ "your ☠️ Curse: Poison eats at the Young Keltir for 8 damage"
      assert text =~ "⛓️ Wind Shackle slides off the Young Keltir"
      assert text =~ "drink a 🧪 Lesser Healing Potion and mend 112 HP"
      refute text =~ "wait for"
      assert text =~ "The Young Keltir runs at you."
      assert text =~ "You set the Young Keltir burning with 🔥 Chill Flame"
      assert text =~ "Your 🔥 Chill Flame burns the Young Keltir for 33 damage"
      assert text =~ "You run at the Young Keltir, and you begin casting 🌪️ Wind Strike."
      assert text =~ "The Young Keltir begins casting 🌪️ Wind Strike."
      # The same heal cast again before the pull is told once, with all it mended.
      assert text =~ "you cast 💚 Heal twice and mend 115 HP"
      # Every skill and item named in its class, led by its emoji.
      for line <- lines, do: refute(line =~ ~r/(cast|use|raise your|drink a) [A-Z]/, line)

      before = Enum.at(read(foe, log, {[{:aura, "Defense Aura"}, {:heal, "Heal", 70, 0}], 60}), 1)
      assert before.head == "Before the fight"
      # A mend before the pull washes its entry as one; an aura alone does not.
      assert before.kind == "heal"
      assert Enum.at(read(foe, log, {[{:aura, "Defense Aura"}], 100}), 1).kind == nil
      assert before.standing == "Foe 100% • You 60%"
      assert before.line == "You raise your 🧱 Defense Aura, and you cast 💚 Heal and mend 70 HP."
    end

    test "a side still standing never reads 0%, nor a hurt one 100%" do
      foe = Rules.monster("Blade Spider")

      [_met, one, two] =
        read(foe, [
          {1, {:blow, 10, false, 0}},
          {1, {:standing, 99, foe.hp - 1}},
          {2, {:blow, 10, false, 0}},
          {2, {:standing, 1, 1}}
        ])

      assert one.standing == "Foe 99% • You 99%"
      assert two.standing == "Foe 1% • You 1%"
    end

    test "a round is washed for a critical hit on either side, else for HP either side mended" do
      foe = Rules.monster("Vaiss Orc")

      log = [
        {1, {:blow, 10, false, 0}},
        {2, {:blow, 40, true, 0}},
        {3, {:cast, "Wind Strike", 50, true, 0}},
        {4, {:drain, "Life Drain", 20, true, 5, 0, 0}},
        {5, {:foe_blow, 30, true, nil, 0}},
        {6, {:foe_blow, 30, true, :caught, 0}},
        {7, {:ignite, "Chill Flame"}},
        {8, {:blow, 9, false, 0}},
        {8, {:foe_blow, 25, true, nil, 0}},
        {9, {:heal, "Self Heal", 40, 0}},
        {10, {:potion, "Lesser Healing Potion", 50, 0}},
        {11, {:drain, "Life Drain", 14, false, 11, 0, 0}},
        {12, {:foe_drain, "NPC HP Drain - Magic 1", 20, 4, 0, 0}},
        {13, {:drain, "Life Drain", 9, false, 0, 0, 0}},
        {14, {:foe_drain, "NPC HP Drain - Magic 1", 20, 0, 0, 0}},
        {15, {:drain, "Vampiric Touch", 30, true, 12, 0, 0}}
      ]

      log = log ++ for(round <- 1..15, do: {round, {:standing, 90, 20}})

      assert foe |> read(log) |> tl() |> Enum.map(& &1.kind) ==
               [nil, "critical", "critical", "critical", "critical", nil, nil, "critical"] ++
                 ["heal", "heal", "heal", "heal", nil, nil, "critical"]
    end

    test "a line opens with a capital in either voice, whatever leads it" do
      foe = Rules.monster("Young Keltir")

      log = [
        {1, {:skill, "Power Strike", 30, 0}},
        {1, {:standing, 90, 20}},
        {2, :foe_miss},
        {2, {:standing, 90, 20}},
        {3, {:blow, 9, false, 0}},
        {3, {:standing, 90, 20}}
      ]

      entries =
        Narrative.build_fight_log(
          foe,
          Rules.ground("obelisk-of-victory"),
          log,
          @weapon,
          {[], 100}
        )

      for entry <- entries, mine? <- [true, false] do
        line = Narrative.voiced(entry.line, mine?)
        assert line =~ ~r/^[A-Z]/, line
        assert unrendered(line) == [], line
      end

      assert plain(Narrative.voiced(Enum.at(entries, 1).line, false)) =~ "They use 💥 Power Strike"
    end
  end

  describe "the hunting grounds" do
    test "each opens on its own ground and village, and has somewhere short to go next" do
      for ground <- Rules.grounds() do
        town = Rules.town(ground.town)
        intro = Narrative.ground_intro(ground, town)

        assert intro =~ ground.name and intro =~ "#{town.emoji} #{town.name}", intro
        assert unrendered(intro) == [], intro

        moves = Narratives.moves(ground.slug)
        assert length(moves) == length(Enum.uniq(moves)) and length(moves) > 1

        # Beside Retreat on one row, on a 360px phone.
        for move <- moves, do: assert(String.length(move) <= 18, move)
      end
    end
  end
end
