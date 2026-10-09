defmodule MiniLineage.Game.Access do
  @moduledoc """
  The one place every navigation rule is enforced. An in-app link, a typed URL and the Back button
  all funnel through `pin_screen/2`, so they cannot disagree.
  """
  alias MiniLineage.Game.Player

  # Carry no action, so every state may read them.
  @readable ~w(races error)

  @doc """
  Where the player is allowed to be: what can be read, for everyone; their town once a character
  exists, which is past character creation; and character creation until then.
  """
  def pin_screen(screen, player) do
    cond do
      screen in @readable -> screen
      Player.started?(player) -> "home"
      true -> "start"
    end
  end

  @doc "Screens that show the sidebar."
  def sidebar?(screen), do: screen == "home"
end
