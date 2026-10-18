defmodule MiniLineage.Game.NarrativeTest do
  @moduledoc """
  The prose the player reads. `Format.fill_template/2` leaves an unrecognised `{placeholder}` in
  place rather than raising, so a typo ships verbatim; these drive every race and path, and fail on
  any brace that survives.
  """
  use ExUnit.Case, async: true

  alias MiniLineage.Game.{Constants, Narrative, Player, Rules}

  @races 0..3

  defp unrendered(text), do: Regex.scan(~r/\{[^}]*\}/, text) |> List.flatten()

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

      log =
        &Narrative.build_fight_log(
          Rules.monster(&1),
          ground,
          [],
          %{max_hp: 100, bow?: false},
          {[], 100}
        )

      [noticed] = log.("Orc Fighter")
      [met] = log.("Young Keltir")

      assert Narrative.alert(noticed) =~
               ~r/^An Orc Fighter, level .*10.*, notices you on the .* and comes at you\.$/

      assert Narrative.alert(met) =~ ~r/^You meet a Young Keltir/
      assert unrendered(Narrative.voiced(noticed, false)) == []
    end

    test "tells a side's swings in one round as one clause, each in order" do
      foe = Rules.monster("Vaiss Orc")
      ground = Rules.ground("obelisk-of-victory")

      log = [
        {1, {:blow, 10, false}},
        {1, {:blow, 9, false}},
        {2, {:blow, 65, true}},
        {2, :miss},
        {2, {:foe_blow, 12, false, nil}},
        {2, :foe_miss},
        {3, {:foe_blow, 8, false, :caught}},
        {3, {:foe_blow, 1, false, :perfect}},
        {3, {:foe_blow, 30, true, nil}},
        {4, {:foe_drain, "NPC HP Drain - Magic 1", 20, 4}},
        {5, {:blow, 11, false}},
        {5, {:foe_blow, 7, false, nil}},
        {6, {:blow, 40, true}},
        {6, :foe_miss}
      ]

      log = log ++ for(round <- 1..6, do: {round, {:standing, 90, 20}})

      [_met | rounds] =
        foe
        |> Narrative.build_fight_log(ground, log, %{max_hp: 100, bow?: false}, {[], 100})
        |> Enum.map(&Narrative.alert/1)

      plain = fn line -> String.replace(line, ~r/<[^>]+>/, "") end
      [one, two, three, four, five, six] = Enum.map(rounds, plain)

      assert one =~ "Round 1: you hit for 10 and 9 ("

      assert two =~
               "Round 2: you swing twice for a critical hit of 65 and a miss, and the Vaiss Orc swings twice at you for a hit of 12 and a miss ("

      assert three =~
               "the Vaiss Orc swings 3 times at you for a hit of 8 that your shield catches, a blow your shield turns aside and a critical hit of 30 ("

      assert four =~ "the Vaiss Orc casts HP Drain on you for 20 and mends 4 HP"
      assert five =~ "Round 5: you hit for 11, and the Vaiss Orc hits you for 7 ("
      assert six =~ "Round 6: you land a critical hit for 40, and the Vaiss Orc misses ("
      for line <- rounds, do: assert(unrendered(line) == [], line)
    end

    test "writes every event a skill makes, open-voiced and with no brace left" do
      foe = Rules.monster("Young Keltir")
      ground = Rules.ground("obelisk-of-victory")

      log = [
        {1, {:heal, "Self Heal", 42}},
        {1, {:drain, "Life Drain", 14, false, 11}},
        {2, {:drain, "Vampiric Touch", 30, true, 12}},
        {2, {:drain, "Life Drain", 9, false, 0}},
        {2, {:toggle, "Soul Cry"}},
        {3, {:curse, "Curse: Poison", true}},
        {3, {:poison, 8}},
        {4, {:curse, "Wind Shackle", false}},
        {4, {:potion, "Lesser Healing Potion", 112}},
        {4, :waiting},
        {4, :closing},
        {4, :advancing},
        {4, {:begin, "Wind Strike"}},
        {4, {:foe_begin, "NPC Windstrike - Magic 1"}}
      ]

      # Every round ends on where both stand, as the engine writes it.
      log = log ++ for(round <- 1..4, do: {round, {:standing, 90, 20}})

      lines =
        foe
        |> Narrative.build_fight_log(
          ground,
          log,
          %{max_hp: 100, bow?: false},
          {[{:aura, "Defense Aura"}, {:heal, "Heal", 70}, {:heal, "Self Heal", 45}], 60}
        )
        |> Enum.map(&Narrative.alert/1)

      for line <- lines do
        assert unrendered(line) == [], line
        refute line =~ "—", line
      end

      text = Enum.join(lines, "\n")
      assert text =~ "cast Self Heal and mend"
      assert text =~ ~r/cast Life Drain for .*14.* and mend .*11.* HP/
      assert text =~ ~r/Vampiric Touch strikes true for .*30.* and mends .*12.* HP/
      assert text =~ ~r/cast Life Drain for .*9<\/span>,/
      assert text =~ "raise your"
      assert text =~ "Soul Cry"
      assert text =~ "lay Curse: Poison on the Young Keltir"
      assert text =~ "the poison eats"
      assert text =~ "Wind Shackle slides off the Young Keltir"
      assert text =~ "drink a Lesser Healing Potion and mend"
      assert text =~ "you wait for the Young Keltir to come"
      assert text =~ "the Young Keltir runs at you"
      assert text =~ "you run at the Young Keltir"
      assert text =~ "you begin casting Wind Strike"
      assert text =~ "the Young Keltir begins casting Wind Strike"

      assert Enum.at(lines, 1) =~
               ~r/^Before the fight: you raise your .*Defense Aura.*you cast Heal and mend .*Self Heal.*you at/
    end
  end
end
