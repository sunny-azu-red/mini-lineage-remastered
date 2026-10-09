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
        assert Access.pin_screen(unquote(screen), player) == unquote(screen)
      end
    end
  end

  test "a character is in its town, being past character creation" do
    for screen <- ~w(start home battle character nowhere) do
      assert Access.pin_screen(screen, started()) == "home", screen
    end
  end

  test "a visitor is at character creation until they have a character" do
    for screen <- ~w(start home battle character nowhere) do
      assert Access.pin_screen(screen, %Player{}) == "start", screen
    end
  end

  test "only the town shows the sidebar" do
    assert Access.sidebar?("home")
    for screen <- ~w(start races error), do: refute(Access.sidebar?(screen))
  end
end
