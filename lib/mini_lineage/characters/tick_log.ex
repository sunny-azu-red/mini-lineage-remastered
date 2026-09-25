defmodule MiniLineage.Characters.TickLog do
  @moduledoc """
  The one line a tick writes: `[TICK:<id>] <Zone> | HP: <old> -> <new>/<max> (<status>)`.

  Its own module because none of it is state — it reads a player and says what just happened to
  them, which is the whole of what `Characters.Server` wanted it for.
  """
  require Logger

  alias MiniLineage.Game.{Format, Player}

  @doc "Writes the line for one firing. `health_before` is captured ahead of the sweep's clamp."
  # A function, so none of it is computed at the `:info` a release logs at.
  def write(id, player, health_before, expired, changed?) do
    Logger.debug(fn ->
      stats = Player.stats(player)
      difference = player.health - health_before

      "[TICK:#{String.slice(id, 0, 7)}] #{zone(player)} | " <>
        "HP: #{moved(difference, health_before)}#{player.health}/#{stats.max_health} " <>
        "(#{status(player, stats, difference, expired, changed?)})"
    end)
  end

  # Read off the RESTING aura, not the absence of combat: a screen in neither list is its own case,
  # not a mislabelled "Resting".
  defp zone(player) do
    cond do
      has?(player, "combat") -> "In Combat"
      has?(player, "resting") -> "Resting"
      true -> "No Zone"
    end
  end

  # Never asked of the dead, whose process does not tick.
  defp has?(player, id), do: Enum.any?(player.effects, &(&1.id == id))

  defp moved(0, _health_before), do: ""
  defp moved(_difference, health_before), do: "#{health_before} -> "

  defp status(player, stats, difference, expired, changed?) do
    labels = Enum.map_join(expired, ", ", & &1.label)
    lapsed = if labels == "", do: "Effect Expired", else: "#{kind(expired)} Expired: #{labels}"

    cond do
      difference > 0 -> "+#{difference} HPR"
      difference < 0 -> "#{difference} HP | #{lapsed}"
      changed? -> lapsed
      player.health >= stats.max_health -> "Full"
      not has?(player, "resting") -> "Paused"
      stats.regen == 0 -> "0 HPR"
      true -> "Idle"
    end
  end

  defp kind([]), do: "Effect"
  defp kind([first | _rest]), do: first.type |> to_string() |> Format.capitalize()
end
