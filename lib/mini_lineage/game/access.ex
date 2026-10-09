defmodule MiniLineage.Game.Access do
  @moduledoc """
  The one place every navigation rule is enforced. An in-app link, a typed URL and the Back button
  all funnel through `pin_screen/2`, so they cannot disagree.

  A place is `{screen, town}`: the town is a rules §14 slug for the screens that stand in one, and
  nil for the rest.
  """
  alias MiniLineage.Game.Player

  # Carry no action, so every state may read them.
  @readable ~w(races error)

  # Where a character can stand: its town, and that town's Gatekeeper.
  @in_town ~w(town gatekeeper)

  @doc """
  Where the player is allowed to be: what can be read, for everyone; the town it stands in once a
  character exists, which is past character creation; and character creation until then.
  """
  def pin_screen({screen, _town}, _player) when screen in @readable, do: {screen, nil}

  def pin_screen({screen, town}, player) do
    cond do
      not Player.started?(player) -> {"start", nil}
      screen in @in_town and town == player.location -> {screen, town}
      true -> {"town", player.location}
    end
  end

  @doc "Screens that show the sidebar."
  def sidebar?(screen), do: screen in @in_town
end
