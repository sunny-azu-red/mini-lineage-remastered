defmodule MiniLineage.Game.NarrativeTest do
  @moduledoc """
  The prose the player reads. `Format.fill_template/2` leaves an unrecognised `{placeholder}` in
  place rather than raising, so a typo ships verbatim; these drive every welcome for every race and
  path, and fail on any brace that survives.
  """
  use ExUnit.Case, async: true

  alias MiniLineage.Game.{Constants, Narrative, Narratives, Player, Rng, Rules}

  @races 0..3
  # More than the welcome pool, so every index of it is drawn.
  @sweeps 24

  # `random_element/1` indexes with `floor(random() * length)`, so pinning the source to a constant
  # pins the index. Sweeping the constant walks every list end to end.
  defp with_draw(value, fun) do
    Rng.put_source(fn -> value end)
    fun.()
  end

  defp draws(count), do: Enum.map(0..(count - 1), &(&1 / count))

  defp unrendered(text), do: Regex.scan(~r/\{[^}]*\}/, text) |> List.flatten()

  describe "the opening flash" do
    test "names the class and the starting town, and renders every welcome cleanly" do
      for race_id <- @races, path <- [:fighter, :mystic], value <- draws(@sweeps) do
        race = Constants.race(race_id)

        {_player, flash} =
          with_draw(value, fn -> Player.initialize(%Player{}, race, path, "Hero") end)

        assert unrendered(flash.text) == [], "race #{race_id}: #{inspect(unrendered(flash.text))}"
        assert flash.text =~ Rules.set(race_id, path).name
        assert flash.text =~ Rules.town(Rules.hometown(race_id)).name
      end
    end
  end

  # The welcome is a fragment joined mid-sentence ("They chose the Orc, and ..."), so a pronoun in
  # its sentence-initial form would read "and Their spirit shines".
  describe "the welcome a run begins with" do
    test "is joined mid-sentence, so none of them starts a new one" do
      race = Constants.race(1)

      for welcome <- Narratives.welcome(), mine <- [true, false] do
        line =
          race
          |> Narrative.build_began(%{
            class_name: "Orc Fighter",
            welcome: welcome,
            build: "a hardy",
            definition: "youth",
            age: 19
          })
          |> Narrative.voiced(mine)

        refute line =~ ~r/, and (Their|Your|They|You)\b/,
               "a welcome capitalises mid-sentence: #{line}"
      end
    end
  end
end
