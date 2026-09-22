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

  # Nothing on these can be acted on — not one `phx-click` between them — so there is nothing for
  # any state to be kept away from. The pin is about what may be DONE, not what may be read.
  @readable ~w(character highscores statistics races error)

  describe "every state" do
    for screen <- @readable do
      test "may read #{screen}, whoever they are" do
        for player <- [unstarted(), alive(), ambushed(), dead()] do
          assert Access.pin_screen(unquote(screen), player) == unquote(screen)
        end
      end
    end
  end

  describe "a living character" do
    test "cannot reach character creation, being past it" do
      assert Access.pin_screen("start", alive()) == "home"
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
    for blocked <- ~w(battle inn weapons armors suicide death home) do
      test "cannot reach #{blocked}" do
        assert Access.pin_screen(unquote(blocked), unstarted()) == "start"
      end
    end

    test "can reach character creation, having no character yet" do
      assert Access.pin_screen("start", unstarted()) == "start"
    end
  end

  describe "a dead character" do
    for target <- ~w(home inn battle weapons start) do
      test "is pinned to the death screen when trying to reach #{target}" do
        assert Access.pin_screen(unquote(target), dead()) == "death"
      end
    end

    test "may stay on the death screen" do
      assert Access.pin_screen("death", dead()) == "death"
    end

    test "may look back at who they were, which is a retrospective rather than a status page" do
      assert Access.pin_screen("character", dead()) == "character"
    end

    test "and may see where the run they just finished now stands" do
      # The Halls list them from the moment they chose a race, so shutting the dead out of the
      # board would hide them from the one page their run exists on.
      assert Access.pin_screen("highscores", dead()) == "highscores"
      assert Access.pin_screen("character", dead()) == "character"
    end

    test "and those exceptions do not widen: everything they could ACT on is still their ending" do
      # The guard against a screen carrying an action being let through by accident.
      for screen <- ~w(home inn weapons armors battle suicide start death) do
        expected = if screen == "death", do: "death", else: "death"
        assert Access.pin_screen(screen, dead()) == expected, screen
      end
    end
  end

  describe "an ambushed character" do
    for target <- ~w(home inn weapons armors suicide start) do
      test "is pinned to the battleground when trying to reach #{target}" do
        assert Access.pin_screen(unquote(target), ambushed()) == "battle"
      end
    end

    # Reading is not escaping. Walking off does not clear `ambushed`, so the moment they ask for a
    # screen they could act on they are back in the fight, with the same ambush waiting on it.
    test "but may still read, because none of that is a way out" do
      for screen <- @readable do
        assert Access.pin_screen(screen, ambushed()) == screen, screen
      end

      assert Access.pin_screen("home", ambushed()) == "battle"
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
