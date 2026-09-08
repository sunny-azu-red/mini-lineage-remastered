defmodule MiniLineage.Game.RateLimit do
  @moduledoc """
  In-memory sliding window, no external dependency. Bypassed entirely unless enabled, so local
  development is never throttled — matching the reference, which keyed that off a release build.
  """
  use GenServer

  @table :mini_lineage_rate_limit

  @limits %{
    battle: %{window_ms: 60_000, limit: 60},
    shop: %{window_ms: 60_000, limit: 30},
    flood: %{window_ms: 60_000, limit: 300}
  }

  def start_link(_opts), do: GenServer.start_link(__MODULE__, :ok, name: __MODULE__)

  @impl true
  def init(:ok) do
    :ets.new(@table, [:named_table, :public, :duplicate_bag, read_concurrency: true])
    schedule_sweep()

    {:ok, %{}}
  end

  @impl true
  def handle_info(:sweep, state) do
    now = System.monotonic_time(:millisecond)
    widest = @limits |> Map.values() |> Enum.map(& &1.window_ms) |> Enum.max()

    :ets.select_delete(@table, [{{:_, :"$1"}, [{:<, :"$1", now - widest}], [true]}])
    schedule_sweep()

    {:noreply, state}
  end

  defp schedule_sweep, do: Process.send_after(self(), :sweep, 60_000)

  @doc "Returns `:ok`, or `{:error, retry_after_ms}` when the window is full."
  def check(key, limiter) when is_map_key(@limits, limiter) do
    if Application.get_env(:mini_lineage, :rate_limit, false),
      do: consume(key, limiter),
      else: :ok
  end

  defp consume(key, limiter) do
    %{window_ms: window_ms, limit: limit} = @limits[limiter]
    now = System.monotonic_time(:millisecond)
    cutoff = now - window_ms

    fresh =
      @table
      |> :ets.lookup({key, limiter})
      |> Enum.map(&elem(&1, 1))
      |> Enum.filter(&(&1 > cutoff))

    if length(fresh) >= limit do
      {:error, Enum.min(fresh) + window_ms - now}
    else
      :ets.insert(@table, {{key, limiter}, now})
      :ok
    end
  end
end
