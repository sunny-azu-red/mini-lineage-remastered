defmodule MiniLineage.Characters.TickLog do
  @moduledoc "The one line a tick writes: `[TICK:<id>] HP: <old> -> <new>/<max> (<status>)`."
  require Logger

  alias MiniLineage.Game.Player

  @doc "Writes the line for one firing. A function, so nothing is computed at a release's level."
  def write(id, player, health_before, healed?) do
    Logger.debug(fn ->
      max_hp = Player.stats(player).max_hp
      moved = if player.health == health_before, do: "", else: "#{health_before} -> "
      status = if healed?, do: "+#{player.health - health_before} HPR", else: "Full"

      "[TICK:#{String.slice(id, 0, 7)}] HP: #{moved}#{player.health}/#{max_hp} (#{status})"
    end)
  end
end
