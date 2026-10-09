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

  test "only a town and its Gatekeeper show the sidebar" do
    for screen <- ~w(town gatekeeper), do: assert(Access.sidebar?(screen))
    for screen <- ~w(start character races error), do: refute(Access.sidebar?(screen))
  end
end
