defmodule MiniLineage.Game.Access do
  @moduledoc """
  The one place every navigation rule is enforced. An in-app link, a typed URL and the Back button
  all funnel through `pin_screen/2`, so they cannot disagree.
  """
  alias MiniLineage.Game.Player

  # The pin gates what may be DONE, not read: these carry no `phx-click`, so no state is kept off
  # them. An ambushed reader escapes nothing by looking.
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

  @doc "Whether the Konami sequence can touch this run, which decides whether keys are sent."
  def konami?(view), do: view.started and not view.dead and not view.cheated

  @doc "An allowlist, not derived: \"has a character\" is a different question."
  def sidebar?(screen), do: screen in ~w(home battle weapons armors inn suicide death)
end
