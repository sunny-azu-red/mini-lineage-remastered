defmodule MiniLineage.Game.Access do
  @moduledoc """
  The one place every navigation rule is enforced. An in-app link, a typed URL and the Back button
  all funnel through `pin_screen/2`, so they cannot disagree.

  A place is `{screen, town}`: the town is a rules §14 slug for the screens that stand in one, and
  nil for the rest.
  """
  alias MiniLineage.Game.{Player, Rules}

  # Carry no action, so every state may read them. The second half of the place is the Halls'
  # lineage filter, which changes what is read and nothing else.
  @readable ~w(races error highscores)

  # Where a character can stand: its town, that town's Gatekeeper, and its hunting ground.
  @trader ["trader" | Enum.map(MiniLineageWeb.Paths.trader_pages(), &("trader-" <> &1))]
  @in_town ~w(town gatekeeper hunt trainer) ++ @trader

  @doc """
  Where the player is allowed to be: what can be read, for everyone; the town it stands in, and its
  own character page, once a character exists, which is past character creation; and character
  creation until then.
  """
  def pin_screen({"highscores", lineage}, _player), do: {"highscores", lineage}
  def pin_screen({screen, _town}, _player) when screen in @readable, do: {screen, nil}

  def pin_screen({screen, town}, player) do
    cond do
      not Player.started?(player) ->
        {"start", nil}

      screen == "hunt" and town == player.location and Rules.ground_of(town) != nil ->
        {screen, town}

      screen in @trader and town == player.location and Rules.village?(town) ->
        {screen, town}

      screen == "trainer" and town == player.location and town == Rules.hometown(player.race_id) ->
        {screen, town}

      screen in ~w(town gatekeeper) and town == player.location ->
        {screen, town}

      screen in ~w(character inventory) ->
        {screen, nil}

      true ->
        {"town", player.location}
    end
  end

  @doc "Screens that show the sidebar."
  def sidebar?(screen), do: screen in @in_town
end
