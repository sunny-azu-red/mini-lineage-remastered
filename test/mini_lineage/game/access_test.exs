defmodule MiniLineage.Game.AccessTest do
  @moduledoc """
  The screen-access policy, stated once, end to end: every navigation funnels through
  `pin_screen/2`, so a link, a typed URL and Back cannot disagree.
  """
  use ExUnit.Case, async: true

  alias MiniLineage.Game.{Access, Constants, Player}

  defp started do
    {player, _} = Player.initialize(%Player{}, Constants.race(0), :fighter, "Started")
    player
  end

  # Nothing on these can be acted on, so there is nothing for any state to be kept away from.
  for screen <- ~w(races error) do
    test "anybody may read #{screen}" do
      for player <- [%Player{}, started()] do
        assert Access.pin_screen({unquote(screen), nil}, player) == {unquote(screen), nil}
      end
    end
  end

  test "anybody may read the Halls, overall or for one lineage, and the filter is kept" do
    for player <- [%Player{}, started()], lineage <- [nil, "dark-elf"] do
      assert Access.pin_screen({"highscores", lineage}, player) == {"highscores", lineage}
    end
  end

  test "a character may stand in its own town, and at that town's Gatekeeper" do
    for screen <- ~w(town gatekeeper) do
      assert Access.pin_screen({screen, "talking-island"}, started()) ==
               {screen, "talking-island"}
    end
  end

  test "a character may read its own page, from wherever it stands" do
    assert Access.pin_screen({"character", nil}, started()) == {"character", nil}

    assert Access.pin_screen({"character", nil}, %{started() | location: "gludio"}) ==
             {"character", nil}
  end

  test "and anywhere else puts it back in the town it stands in" do
    for place <- [
          {"start", nil},
          {"town", "gludio"},
          {"gatekeeper", "orc-village"},
          {"town", nil},
          {"battle", "talking-island"},
          {"nowhere", nil}
        ] do
      assert Access.pin_screen(place, started()) == {"town", "talking-island"}, inspect(place)
    end
  end

  test "which follows the character when it travels" do
    moved = %{started() | location: "gludio"}

    assert Access.pin_screen({"town", "gludio"}, moved) == {"town", "gludio"}
    assert Access.pin_screen({"town", "talking-island"}, moved) == {"town", "gludio"}
  end

  # Rules §21: a run that has ended stays on the ground it fell on, and only looks from there.
  defp fallen, do: %{started() | dead: true, health: 0, fell_at: "obelisk-of-victory"}

  test "a fallen run stands on the ground it fell on, and may read its own pages" do
    assert Access.pin_screen({"hunt", "talking-island"}, fallen()) == {"hunt", "talking-island"}

    for screen <- ~w(character inventory) do
      assert Access.pin_screen({screen, nil}, fallen()) == {screen, nil}
    end

    for place <- [{"races", nil}, {"error", nil}, {"highscores", "human"}] do
      assert Access.pin_screen(place, fallen()) == place
    end
  end

  test "and anywhere it could act puts it back there" do
    for place <- [
          {"start", nil},
          {"town", "talking-island"},
          {"gatekeeper", "talking-island"},
          {"trader", "talking-island"},
          {"trader-weapon", "talking-island"},
          {"guild", "talking-island"},
          {"hunt", "elven-village"},
          {"nowhere", nil}
        ] do
      assert Access.pin_screen(place, fallen()) == {"hunt", "talking-island"}, inspect(place)
    end
  end

  test "a visitor is at character creation until they have a character" do
    for place <- [
          {"start", nil},
          {"town", "talking-island"},
          {"gatekeeper", "gludio"},
          {"character", nil},
          {"nowhere", nil}
        ] do
      assert Access.pin_screen(place, %Player{}) == {"start", nil}, inspect(place)
    end
  end

  test "a town's places and the inventory show the sidebar, and nothing else" do
    traders = Enum.map(MiniLineageWeb.Paths.trader_pages(), &("trader-" <> &1))

    for screen <- ~w(town gatekeeper hunt guild trader inventory) ++ traders,
        do: assert(Access.sidebar?(screen), screen)

    for screen <- ~w(start character races error highscores),
        do: refute(Access.sidebar?(screen), screen)
  end
end
