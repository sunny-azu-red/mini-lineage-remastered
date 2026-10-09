defmodule MiniLineage.Characters.TickLog do
  @moduledoc """
  The one line a tick writes:
  `[TICK:<id>] HP: <old> -> <new>/<max> | MP: <old> -> <new>/<max> (<what it restored>)`.
  """
  require Logger

  alias MiniLineage.Game.Player

  @doc "Writes the line for one firing. A function, so nothing is computed at a release's level."
  def write(id, player, before, healed?) do
    Logger.debug(fn ->
      stats = Player.stats(player)
      hp = bar(before.health, player.health, stats.max_hp)
      mp = bar(before.mp, player.mp, stats.max_mp)

      "[TICK:#{String.slice(id, 0, 7)}] HP: #{hp} | MP: #{mp} (#{status(before, player, healed?)})"
    end)
  end

  defp bar(same, same, max), do: "#{same}/#{max}"
  defp bar(was, now, max), do: "#{was} -> #{now}/#{max}"

  defp status(_before, _player, false), do: "Full"

  defp status(before, player, true) do
    [{"HP", player.health - before.health}, {"MP", player.mp - before.mp}]
    |> Enum.reject(fn {_bar, gained} -> gained == 0 end)
    |> Enum.map_join(", ", fn {bar, gained} -> "+#{gained} #{bar}" end)
  end
end
