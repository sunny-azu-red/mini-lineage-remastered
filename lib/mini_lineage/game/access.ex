defmodule MiniLineage.Game.Access do
  @moduledoc """
  The one place every navigation rule is enforced. An in-app link, a typed URL and the Back button
  all funnel through `pin_screen/2`, so they cannot disagree — historically they did.
  """
  alias MiniLineage.Game.Player

  # THE PIN IS ABOUT WHAT YOU MAY DO, NOT WHAT YOU MAY READ. These five carry no action at all, not
  # one `phx-click` between them, so no state need be kept off them: an ambushed reader escapes
  # nothing by looking, and a fault is worth being told about whatever has happened to you.
  @readable ~w(character highscores statistics races error)

  # Screens a living character may never be on — 'death' offers "Play Again?", which wipes them,
  # and 'start' is character creation, which they are past.
  @started_blocked ~w(start death)

  @doc """
  Where the player is actually allowed to be. What can be READ is answered first and for everyone;
  after that, death wins outright — before the ambush, because killing a player does not clear
  `ambushed` — then an active ambush, then living-vs-absent character.
  """
  def pin_screen(screen, player) do
    cond do
      screen in @readable -> screen
      player.dead -> "death"
      player.ambushed -> "battle"
      Player.started?(player) -> if screen in @started_blocked, do: "home", else: screen
      true -> "start"
    end
  end

  @doc "Screens that show the sidebar. An allowlist, not derived — \"has a character\" is a different question."
  def sidebar?(screen), do: screen in ~w(home battle weapons armors inn suicide death)
end
