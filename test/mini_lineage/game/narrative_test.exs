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
    test "writes every event a skill makes, open-voiced and with no brace left" do
      foe = Rules.monster("Young Keltir")
      ground = Rules.ground("obelisk-of-victory")

      log = [
        {1, {:heal, "Self Heal", 42}},
        {1, {:aura, "Defense Aura"}},
        {2, {:toggle, "Soul Cry"}},
        {3, {:curse, "Curse: Poison", true}},
        {3, {:poison, 8}},
        {4, {:curse, "Wind Shackle", false}},
        {4, {:potion, "Lesser Healing Potion", 112}}
      ]

      # Every round ends on where both stand, as the engine writes it.
      log = log ++ for(round <- 1..4, do: {round, {:standing, 90, 20}})

      lines =
        foe
        |> Narrative.build_fight_log(ground, log, %{max_hp: 100, bow?: false})
        |> Enum.map(&Narrative.alert/1)

      for line <- lines do
        assert unrendered(line) == [], line
        refute line =~ "—", line
      end

      text = Enum.join(lines, "\n")
      assert text =~ "cast Self Heal and mend"
      assert text =~ "raise your"
      assert text =~ "Soul Cry"
      assert text =~ "lay Curse: Poison on the Young Keltir"
      assert text =~ "the poison eats"
      assert text =~ "Wind Shackle slides off the Young Keltir"
      assert text =~ "drink a Lesser Healing Potion and mend"
    end
  end
end
