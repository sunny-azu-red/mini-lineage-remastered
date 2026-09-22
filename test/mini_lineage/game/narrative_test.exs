defmodule MiniLineage.Game.NarrativeTest do
  @moduledoc """
  Holds the prose the player actually reads.

  `Format.fill_template/2` leaves an unrecognised `{placeholder}` in the string rather than
  raising, so a mistyped variable ships to the player verbatim. These tests drive EVERY template in
  EVERY list, for every race, and fail on any brace that survives rendering — which no sampled
  transcript can promise, since a sample only ever exercises the templates it happened to draw.
  """
  use ExUnit.Case, async: true

  alias MiniLineage.Game.{Constants, Narrative, Narratives, Player, Rng}

  @races 0..3

  # `random_element/1` indexes with `floor(random() * length)`, so pinning the source to a constant
  # pins the index. Sweeping the constant walks every list end to end.
  defp with_draw(value, fun) do
    Rng.put_source(fn -> value end)
    fun.()
  end

  defp draws(count), do: Enum.map(0..(count - 1), &(&1 / count))

  defp started(race_id, opts \\ []) do
    race = Constants.race(race_id)

    %Player{
      name: "Hero",
      race_id: race_id,
      health: race.start_health,
      adena: Keyword.get(opts, :adena, race.start_adena),
      experience: 0,
      weapon_id: Keyword.get(opts, :weapon_id, 0),
      armor_id: Keyword.get(opts, :armor_id, 0)
    }
  end

  defp unrendered(text) when is_binary(text) do
    Regex.scan(~r/\{[^}]*\}/, text) |> List.flatten()
  end

  defp unrendered(nil), do: []

  # Fixed so only the template choice varies: a simulated fight rolls different numbers each sweep,
  # and the same template would then render to different strings.
  defp fixed_result(opts \\ []) do
    %{
      enemies_killed: 3,
      hp_lost: 12,
      damage_blocked: 4,
      xp_gained: 57,
      adena_gained: 18,
      is_critical: Keyword.get(opts, :critical, false),
      is_level_up: Keyword.get(opts, :level_up, false)
    }
  end

  describe "battle narrative" do
    # 24 sweeps: more than the longest template list, so every index of every list is drawn.
    @sweeps 24

    test "every template renders with no placeholder left behind, for every race and outcome" do
      for race_id <- @races,
          critical? <- [true, false],
          level_up? <- [true, false],
          ambushed? <- [true, false],
          value <- draws(@sweeps) do
        player = started(race_id, weapon_id: 3, armor_id: 3)

        narrative =
          with_draw(value, fn ->
            result = fixed_result(critical: critical?, level_up: level_up?)
            Narrative.build_battle(player, result, ambushed?)
          end)

        # A stored line keeps its PRONOUNS open on purpose — who it is told to is not known until
        # somebody opens a page — so what has to close is everything else, and then the pronouns
        # too once a reader is known. Checked for both readers, since they fill different words.
        for {key, line} <- narrative, is_binary(line), mine? <- [true, false] do
          spoken = Narrative.voiced(line, mine?)

          assert unrendered(spoken) == [],
                 "#{key} left #{inspect(unrendered(spoken))} for race #{race_id}: #{spoken}"

          refute spoken =~ ~r/\byou\b/i and not mine?,
                 "#{key} says \"you\" to somebody reading about a stranger: #{spoken}"
        end
      end
    end

    test "each list is drawn end to end, so the sweep above really does reach every template" do
      lists = %{
        kill_line: Narratives.kill(),
        deflection_line: Narratives.deflection(),
        outcome_line: Narratives.outcome(),
        next_move: Narratives.moves()
      }

      seen =
        for value <- draws(@sweeps), reduce: %{} do
          acc ->
            player = started(0, weapon_id: 3, armor_id: 3)

            narrative =
              with_draw(value, fn ->
                Narrative.build_battle(player, fixed_result(), false)
              end)

            Enum.reduce(Map.keys(lists), acc, fn key, acc ->
              Map.update(acc, key, MapSet.new([narrative[key]]), &MapSet.put(&1, narrative[key]))
            end)
        end

      for {key, templates} <- lists do
        assert MapSet.size(seen[key]) == length(templates),
               "#{key}: saw #{MapSet.size(seen[key])} distinct lines for #{length(templates)} templates"
      end
    end

    test "a critical hit adds a line, and an ordinary hit does not" do
      player = started(0)

      crit =
        with_draw(0.0, fn ->
          Narrative.build_battle(player, fixed_result(critical: true), false)
        end)

      plain =
        with_draw(0.0, fn ->
          Narrative.build_battle(player, fixed_result(critical: false), false)
        end)

      assert is_binary(crit.crit_line)
      assert plain.crit_line == nil
    end

    test "an ambush names the foe and asks to be faced; no ambush says nothing at all" do
      player = started(0)

      ambushed = with_draw(0.0, fn -> Narrative.build_battle(player, fixed_result(), true) end)
      calm = with_draw(0.0, fn -> Narrative.build_battle(player, fixed_result(), false) end)

      assert is_binary(ambushed.ambush_line)
      assert ambushed.fight_prompt in ["Face your Foe!", "Fight them!"]
      assert calm.ambush_line == nil
      assert calm.fight_prompt == nil
    end

    test "the narrative names the gear the character is actually carrying" do
      player = started(0, weapon_id: 4, armor_id: 4)
      weapon = Constants.weapon(4)

      lines =
        for value <- draws(@sweeps) do
          with_draw(value, fn -> Narrative.build_battle(player, fixed_result(), false) end).kill_line
        end

      assert Enum.any?(lines, &String.contains?(&1, weapon.name)),
             "no kill line named the equipped weapon"
    end
  end

  describe "race traits" do
    test "render for every race with nothing left unfilled" do
      for race_id <- @races do
        traits = Narrative.build_race_traits(Constants.race(race_id))
        assert unrendered(traits) == [], "race #{race_id}: #{inspect(unrendered(traits))}"
        refute traits == ""
      end
    end

    test "quote the race's own numbers, not another's" do
      for race_id <- @races do
        race = Constants.race(race_id)
        traits = Narrative.build_race_traits(race)

        assert String.contains?(traits, to_string(race.start_health)),
               "race #{race_id} traits never mention its #{race.start_health} starting health"
      end
    end
  end

  describe "the opening flash" do
    test "names the race and renders every welcome line cleanly" do
      for race_id <- @races, value <- draws(@sweeps) do
        race = Constants.race(race_id)

        {_player, flash} =
          with_draw(value, fn -> Player.initialize(%Player{}, race, "Hero") end)

        assert unrendered(flash.text) == [], "race #{race_id}: #{inspect(unrendered(flash.text))}"
        assert String.contains?(flash.text, race.label)
      end
    end
  end

  describe "the fight that killed them" do
    # `resolve_battle_outcome/2` returns the moment health reaches zero, BEFORE the XP, the Adena
    # and every counter are credited. A line naming any of them describes a reward never given.
    test "names no reward, because a fatal fight pays none" do
      fighter = started(0, weapon_id: 3, armor_id: 3)
      result = fixed_result()
      {killed, _} = Player.resolve_battle_outcome(%{fighter | health: 1}, result)

      assert killed.dead
      assert killed.experience == fighter.experience, "a fatal fight granted XP"
      assert killed.adena == fighter.adena, "a fatal fight granted Adena"

      narrative = Narrative.build_battle(killed, result, false)

      refute narrative.deflection_line, "the deflection line names the XP that was never earned"
      refute narrative.outcome_line =~ "Adena"
      refute narrative.outcome_line =~ "HP"
    end

    test "and says how it ended in its place" do
      fighter = started(0, weapon_id: 3, armor_id: 3)
      {killed, _} = Player.resolve_battle_outcome(%{fighter | health: 1}, fixed_result())

      narrative = Narrative.build_battle(killed, fixed_result(), false)

      # Second person, as the whole chronicle is, and with its pronouns already filled.
      assert narrative.outcome_line == Narrative.death_reason(killed.death_reason, true)
      refute narrative.outcome_line =~ "{"
    end

    # Nothing the fighter did in it counted — not the rewards, and not the kills, which are never
    # added to `total_enemies_killed` either. The foes did not fall; the fighter did.
    test "and claims no kill, because the ones it named were never counted" do
      fighter = started(0, weapon_id: 3, armor_id: 3)
      before = fighter.total_enemies_killed
      {killed, _} = Player.resolve_battle_outcome(%{fighter | health: 1}, fixed_result())

      assert killed.total_enemies_killed == before, "a fatal fight counted kills"

      narrative = Narrative.build_battle(killed, fixed_result(), false)

      refute narrative.kill_line
      refute narrative.crit_line
    end
  end

  describe "death lines" do
    # Written once with its pronouns left open, so what has to hold is that it closes — for the
    # fallen player reading their own record, and for the stranger reading it in the Halls.
    test "every one is real prose for either reader, with no placeholder and no blank" do
      for template <- [Narratives.death_cheated(), Narratives.death_coward() | Narratives.death()],
          mine? <- [true, false] do
        line = Narrative.death_reason(template, mine?)

        assert unrendered(line) == [],
               "#{template} left #{inspect(unrendered(line))} for #{mine?}"

        refute String.trim(line) == ""
      end
    end

    test "and reads differently depending on who is reading it" do
      for template <- [Narratives.death_cheated(), Narratives.death_coward() | Narratives.death()] do
        refute Narrative.death_reason(template, true) == Narrative.death_reason(template, false),
               "#{template} says the same thing to a stranger as to the run it ended"
      end
    end

    test "a death reason is drawn from that list" do
      for value <- draws(@sweeps) do
        player = with_draw(value, fn -> Player.kill(started(0)) end)
        assert player.death_reason in Narratives.death()
      end
    end
  end

  describe "purchase messages" do
    test "a completed purchase names the item and takes exactly its price" do
      for {type, items} <- [
            {"weapon", Constants.weapons()},
            {"armor", Constants.armors()},
            {"food", Constants.foods()}
          ],
          {item, id} <- Enum.with_index(items),
          # The starting weapon and armor are equipped, never sold.
          not (type in ["weapon", "armor"] and id == 0) do
        player = started(0, adena: 2_000_000)
        {after_buy, result} = Player.purchase(player, type, id)

        assert result.success, "#{type} #{id} (#{item.name}) was refused: #{result.text}"
        assert String.contains?(result.text, item.name), "message never named #{item.name}"
        assert unrendered(result.text) == []
        assert after_buy.adena == player.adena - item.cost
      end
    end

    test "an unaffordable item is refused by name, and costs nothing" do
      player = started(0, adena: 0)
      {unchanged, result} = Player.purchase(player, "weapon", 5)
      weapon = Constants.weapon(5)

      refute result.success
      assert String.contains?(result.text, weapon.name)
      assert String.contains?(result.text, "not have enough 🪙 Adena")
      assert unchanged.adena == 0
    end

    test "buying what you already wear is refused by name, and costs nothing" do
      player = started(0, adena: 2_000_000, weapon_id: 2)
      {unchanged, result} = Player.purchase(player, "weapon", 2)

      refute result.success
      assert String.contains?(result.text, Constants.weapon(2).name)
      assert unchanged.adena == player.adena
    end
  end
end
