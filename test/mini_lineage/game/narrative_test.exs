defmodule MiniLineage.Game.NarrativeTest do
  @moduledoc """
  The prose the player reads. `Format.fill_template/2` leaves an unrecognised `{placeholder}` in
  place rather than raising, so a typo ships verbatim; these drive every race and path, and fail on
  any brace that survives.
  """
  use ExUnit.Case, async: true

  alias MiniLineage.Game.{Constants, Narrative, Narratives, Player, Rules}

  @races 0..3

  defp unrendered(text), do: Regex.scan(~r/\{[^}]*\}/, text) |> List.flatten()

  @weapon %{max_hp: 100, bow?: false, hp: 100}

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
    test "an aggressive monster comes at the character, a passive one is met" do
      ground = Rules.ground("obelisk-of-victory")

      [noticed] =
        Narrative.build_fight_log(Rules.monster("Orc Fighter"), ground, [], @weapon, {[], 80})

      [met] =
        Narrative.build_fight_log(Rules.monster("Young Keltir"), ground, [], @weapon, {[], 80})

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

    test "tells a side's swings in one round as one clause, each in order" do
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
               line: "You hit for 10 and 9 damage."
             }

      assert two.head == "Round 2 • 1.7s"

      assert two.line ==
               "You swing twice for a critical hit of 65 damage and a miss, and the Vaiss Orc swings twice at you for a hit of 12 damage and a miss."

      assert three.line ==
               "The Vaiss Orc swings 3 times at you for a hit of 8 damage that your shield catches, a blow your shield turns aside and a critical hit of 30 damage."

      assert four.line == "The Vaiss Orc casts HP Drain on you for 20 damage and mends 4 HP."

      assert five == %{
               five
               | head: "Round 5 • 6.7s",
                 line: "You hit for 11 damage, and the Vaiss Orc hits you for 7 damage."
             }

      assert six.line == "You land a critical hit for 40 damage, and the Vaiss Orc misses."

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
        {7, {:burn, "Chill Flame", 3, 2}}
      ]

      log = log ++ for(round <- 1..7, do: {round, {:standing, 90, 20}})

      [_met | rounds] = read(foe, log)

      assert Enum.map(rounds, & &1.line) == [
               "You hit for 10 and 19 damage (14 overkill).",
               "The Vaiss Orc hits you for 20 damage (19 overkill).",
               "You cast Life Drain for 20 damage (14 overkill) and mend 6 HP (2 overheal).",
               "You drink a Lesser Healing Potion and mend 112 HP (31 overheal).",
               "You swing twice for a hit of 9 damage and a critical hit of 20 damage (15 overkill).",
               "The Vaiss Orc casts HP Drain on you for 20 damage (19 overkill).",
               "Your Chill Flame tick burns for 5 damage (2 overkill)."
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
      assert {one.head, one.line} == {"Round 1 • 0.0s", "You begin casting Wind Strike."}

      assert {three.head, three.line} ==
               {"Round 3 • 3.3s",
                "You cast Wind Strike for 112 damage, and the Goblin Scout runs at you."}

      assert {five.head, five.line} == {"Round 5 • 6.7s", "You hit for 9 damage."}
      # A round with something else in it says why the character did nothing.
      assert {seven.head, seven.line} ==
               {"Round 7 • 10.0s", "As you cast, the Goblin Scout hits you for 5 damage."}
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

      assert one.line == "You miss twice, and the Vaiss Orc misses 3 times."
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
        {3, {:poison, "Curse: Poison", 8}},
        {4, {:curse, "Wind Shackle", false}},
        {4, {:potion, "Lesser Healing Potion", 112, 0}},
        {4, :waiting},
        {4, :closing},
        {4, :advancing},
        {4, {:begin, "Wind Strike"}},
        {4, {:foe_begin, "NPC Windstrike - Magic 1"}},
        {5, {:cast, "Chill Flame", 0, false, 0}},
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

      text = Enum.join(lines, "\n")
      assert text =~ "cast Self Heal and mend"
      assert text =~ ~r/cast Life Drain for .*14.* and mend .*11.* HP/
      assert text =~ ~r/Vampiric Touch strikes true for .*30.* and mends .*12.* HP/
      assert text =~ ~r/cast Life Drain for .*9 damage<\/span>,/
      assert text =~ "raise your"
      assert text =~ ~r/you let out a .*Soul Cry.* to make your blows heavier/
      assert text =~ "lay Curse: Poison on the Young Keltir"
      assert text =~ ~r/your Curse: Poison tick deals .*8/
      assert text =~ "Wind Shackle slides off the Young Keltir"
      assert text =~ "drink a Lesser Healing Potion and mend"
      refute text =~ "wait for"
      assert text =~ "the Young Keltir runs at you"
      assert text =~ "You set the Young Keltir burning with Chill Flame"
      assert text =~ ~r/Your Chill Flame tick burns for .*33/
      assert text =~ "you run at the Young Keltir"
      assert text =~ "you begin casting Wind Strike"
      assert text =~ "the Young Keltir begins casting Wind Strike"

      before = Enum.at(read(foe, log, {[{:aura, "Defense Aura"}, {:heal, "Heal", 70, 0}], 60}), 1)
      assert before.head == "Before the fight"
      # A mend before the pull washes its entry as one; an aura alone does not.
      assert before.kind == "heal"
      assert Enum.at(read(foe, log, {[{:aura, "Defense Aura"}], 100}), 1).kind == nil
      assert before.standing == "Foe 100% • You 60%"
      assert before.line =~ ~r/^You raise your Defense Aura, and you cast Heal and mend 70 HP\.$/
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
        {7, {:cast, "Chill Flame", 0, true, 0}},
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

      assert Narrative.voiced(Enum.at(entries, 1).line, false) =~ "Their Power Strike"
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
