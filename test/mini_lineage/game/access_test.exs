defmodule MiniLineage.Game.AccessTest do
  @moduledoc """
  The screen-access policy, stated once, end to end. Ported from the reference's acceptance suite:
  the rules are only meaningful together, and every navigation funnels through `pin_screen/2`, so
  an in-app link, a typed URL and the Back button cannot disagree.
  """
  use ExUnit.Case, async: true

  alias MiniLineage.Game.{Access, Constants, Player}

  defp alive do
    {player, _} = Player.initialize(%Player{}, Constants.race(0), "Alive")
    player
  end

  defp unstarted, do: %Player{}
  defp dead, do: %{alive() | dead: true}
  defp ambushed, do: %{alive() | ambushed: true}

  describe "a living character" do
    for blocked <- ~w(statistics races start) do
      test "cannot reach #{blocked} — those belong to character creation" do
        assert Access.pin_screen(unquote(blocked), alive()) == "home"
      end
    end

    # The serious one: the death screen offers "Play Again?", which resets the character.
    test "cannot reach the death screen" do
      assert Access.pin_screen("death", alive()) == "home"
    end

    for allowed <- ~w(home inn weapons armors battle suicide character highscores) do
      test "can still reach #{allowed}" do
        assert Access.pin_screen(unquote(allowed), alive()) == unquote(allowed)
      end
    end
  end

  describe "a visitor with no character" do
    for blocked <- ~w(battle inn weapons armors suicide character death home) do
      test "cannot reach #{blocked}" do
        assert Access.pin_screen(unquote(blocked), unstarted()) == "start"
      end
    end

    for allowed <- ~w(start statistics races highscores) do
      test "can reach #{allowed}" do
        assert Access.pin_screen(unquote(allowed), unstarted()) == unquote(allowed)
      end
    end
  end

  describe "a dead character" do
    for target <- ~w(home inn battle highscores statistics start) do
      test "is pinned to the death screen when trying to reach #{target}" do
        assert Access.pin_screen(unquote(target), dead()) == "death"
      end
    end

    test "may stay on the death screen" do
      assert Access.pin_screen("death", dead()) == "death"
    end

    test "may look back at who they were, which is the one screen that is a retrospective" do
      assert Access.pin_screen("character", dead()) == "character"
    end

    test "and that exception does not widen: everything else is still the death screen" do
      # The list above covers the screens a player would try; this is the guard against a new one
      # being added to @dead_allowed by accident.
      for screen <- ~w(home inn weapons armors battle suicide highscores statistics races start) do
        assert Access.pin_screen(screen, dead()) == "death", screen
      end
    end
  end

  describe "an ambushed character" do
    for target <- ~w(home inn weapons armors character highscores) do
      test "is pinned to the battleground when trying to reach #{target}" do
        assert Access.pin_screen(unquote(target), ambushed()) == "battle"
      end
    end

    # Death wins outright, because killing a player does not clear `ambushed`.
    test "who is also dead goes to the death screen, not the battleground" do
      assert Access.pin_screen("home", %{ambushed() | dead: true}) == "death"
    end
  end

  test "the sidebar allowlist is not merely \"has a character\"" do
    for screen <- ~w(home battle weapons armors inn suicide death),
        do: assert(Access.sidebar?(screen))

    for screen <- ~w(character highscores statistics races start error),
        do: refute(Access.sidebar?(screen))
  end
end
