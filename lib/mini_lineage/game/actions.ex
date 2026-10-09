defmodule MiniLineage.Game.Actions do
  @moduledoc """
  Every state-changing action, as a function from a player to `{player, result}` — the shape
  `Characters.mutate/2` runs inside the character's process. Each declares its own preconditions:
  client-side routing is convenience, these guards are the boundary.
  """
  alias MiniLineage.Game.{Constants, Format, Narrative, Player, Rules, Version}

  @errors %{
    already_started: "You already have a character.",
    invalid: "That is not something you can do.",
    closed: "The Gatekeeper cannot send you there yet.",
    poor: "You cannot pay the Gatekeeper's fee."
  }

  # Not a rule of the game: what a debug build puts in a purse so the Gatekeeper can be tried.
  @dev_adena 10_000

  @doc "Creates the character: a race, a path and a name, all checked here."
  def start(player, race_id, path, name) do
    cond do
      Player.started?(player) ->
        {player, {:error, :already_started, @errors.already_started}}

      true ->
        case validate_start(race_id, path, name) do
          :invalid -> {player, {:error, :invalid, @errors.invalid}}
          {:ok, race, path, name} -> begin(player, race, path, name)
        end
    end
  end

  defp begin(player, race, path, name) do
    {player, flash} = Player.initialize(player, race, path, name)
    {player, {:ok, flash}}
  end

  defp validate_start(race_id, path, name) do
    config = Constants.character()
    trimmed = String.trim(to_string(name))
    length = String.length(trimmed)

    with {race_id, ""} <- Integer.parse(to_string(race_id)),
         %{} = race <- Enum.find(Constants.races(), &(&1.id == race_id)),
         {:ok, path} <- path(path),
         true <- length >= config.name_min_length and length <= config.name_max_length do
      {:ok, race, path, trimmed}
    else
      _ -> :invalid
    end
  end

  @doc "Rules §14: the Gatekeeper sends a character along a route out of its town, for the fee."
  def travel(player, to) do
    route = Player.started?(player) && Rules.route(player.location, to)

    cond do
      !route -> {player, {:error, :invalid, @errors.invalid}}
      !Rules.town(to).open? -> {player, {:error, :closed, @errors.closed}}
      player.adena < route.fee -> {player, {:error, :poor, @errors.poor}}
      true -> arrive(player, Rules.town(to), route.fee)
    end
  end

  defp arrive(player, town, fee) do
    player = %{player | location: town.slug, adena: player.adena - fee}
    {player, {:ok, %{text: Narrative.alert(Narrative.build_arrived(town, fee)), type: :info}}}
  end

  @doc "Debug builds only: Adena to try the Gatekeeper with, every time it is asked for."
  def dev_adena(player) do
    if Version.debug_build?() and Player.started?(player) do
      text =
        ~s(A debug build drops <span class="adena">#{Format.number(@dev_adena)} Adena</span> into your purse.)

      {%{player | adena: player.adena + @dev_adena}, {:ok, %{text: text, type: :info}}}
    else
      {player, {:error, :invalid, @errors.invalid}}
    end
  end

  # Named here rather than converted: the form's value is untrusted, and `String.to_atom/1` on it
  # would mint atoms.
  defp path("fighter"), do: {:ok, :fighter}
  defp path("mystic"), do: {:ok, :mystic}
  defp path(_other), do: :invalid
end
