defmodule MiniLineage.Game.Clock do
  @moduledoc """
  Wall-clock milliseconds, overridable per process. Effect expiry is measured against this, so a
  simulation can hold time still instead of depending on how fast it happens to run.
  """
  @key :mini_lineage_clock

  @doc "Freezes time for the calling process at `ms`."
  def put_now(ms) when is_integer(ms), do: Process.put(@key, ms)

  def now_ms do
    case Process.get(@key) do
      nil -> System.system_time(:millisecond)
      ms -> ms
    end
  end
end
