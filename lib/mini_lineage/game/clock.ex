defmodule MiniLineage.Game.Clock do
  @moduledoc """
  Wall-clock milliseconds, overridable per process. Effect expiry is measured against this, so a
  simulation can hold time still instead of depending on how fast it happens to run.
  """
  @key :mini_lineage_clock

  @doc "Freezes time for the calling process at `ms`."
  def put_now(ms) when is_integer(ms), do: Process.put(@key, ms)

  @doc """
  The same instant as a `DateTime`, for a row that is dated rather than measured against.

  Built from microseconds because the log's timestamps are `:utc_datetime_usec`, and Ecto refuses
  a coarser one rather than padding it.
  """
  def now, do: to_datetime(now_ms())

  @doc "An epoch-millisecond instant, such as an effect's `expires_at`, as the log dates it."
  def to_datetime(ms), do: DateTime.from_unix!(ms * 1_000, :microsecond)

  def now_ms do
    case Process.get(@key) do
      nil -> System.system_time(:millisecond)
      ms -> ms
    end
  end
end
