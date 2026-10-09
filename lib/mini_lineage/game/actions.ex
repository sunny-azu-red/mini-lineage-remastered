defmodule MiniLineage.Game.Actions do
  @moduledoc """
  Every state-changing action, as a function from a player to `{player, result}` — the shape
  `Characters.mutate/2` runs inside the character's process. Each declares its own preconditions:
  client-side routing is convenience, these guards are the boundary.
  """
  alias MiniLineage.Game.{Constants, Player}

  @errors %{
    already_started: "You already have a character.",
    invalid: "That is not something you can do."
  }

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

  # Named here rather than converted: the form's value is untrusted, and `String.to_atom/1` on it
  # would mint atoms.
  defp path("fighter"), do: {:ok, :fighter}
  defp path("mystic"), do: {:ok, :mystic}
  defp path(_other), do: :invalid
end
