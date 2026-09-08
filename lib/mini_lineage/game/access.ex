defmodule MiniLineage.Game.Access do
  @moduledoc """
  The one place every navigation rule is enforced. An in-app link, a typed URL and the Back button
  all funnel through `pin_screen/2`, so they cannot disagree — historically they did.
  """
  alias MiniLineage.Game.Player

  # The only screens a visitor with no character may reach.
  @unstarted_allowed ~w(start statistics races highscores error)

  # Screens a living character may never be on — 'death' offers "Play Again?", which wipes them.
  @started_blocked ~w(start statistics races death)

  @doc """
  Where the player is actually allowed to be. Death wins outright — checked first because killing
  a player does not clear `ambushed` — then an active ambush, then living-vs-absent character.
  """
  def pin_screen(screen, player) do
    cond do
      player.dead -> "death"
      player.ambushed -> "battle"
      Player.started?(player) -> if screen in @started_blocked, do: "home", else: screen
      true -> if screen in @unstarted_allowed, do: screen, else: "start"
    end
  end

  @doc "Screens that show the sidebar. An allowlist, not derived — \"has a character\" is a different question."
  def sidebar?(screen), do: screen in ~w(home battle weapons armors inn suicide death)
end
