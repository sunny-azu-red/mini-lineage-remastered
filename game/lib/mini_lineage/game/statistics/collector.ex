defmodule MiniLineage.Game.Statistics.Collector do
  @moduledoc """
  Batches the fire-and-forget counters and flushes them as atomic upserts. The reference issued one
  round trip per increment — a single fight fires seven — so they are coalesced over a short window
  instead. Nothing reads these back mid-fight, so the delay is invisible.
  """
  use GenServer

  alias MiniLineage.Game.Statistics
  alias MiniLineage.Repo

  @flush_ms 1_000

  def start_link(_opts), do: GenServer.start_link(__MODULE__, %{}, name: __MODULE__)

  @doc "Writes everything pending now. For tests and shutdown."
  def flush, do: GenServer.call(__MODULE__, :flush)

  @impl true
  def init(_) do
    Process.flag(:trap_exit, true)
    schedule()

    {:ok, %{}}
  end

  @impl true
  def handle_info({:increment, field, amount}, pending),
    do: {:noreply, Map.update(pending, field, amount, &(&1 + amount))}

  def handle_info(:flush, pending) do
    write(pending)
    schedule()

    {:noreply, %{}}
  end

  @impl true
  def handle_call(:flush, _from, pending) do
    write(pending)

    {:reply, :ok, %{}}
  end

  @impl true
  def terminate(_reason, pending), do: write(pending)

  defp schedule, do: Process.send_after(self(), :flush, @flush_ms)

  defp write(pending) do
    for {field, amount} <- pending, amount != 0 do
      Repo.query!(
        "INSERT INTO statistics (name, value) VALUES (?, ?) ON DUPLICATE KEY UPDATE value = value + ?",
        [Atom.to_string(field), amount, amount]
      )
    end

    :ok
  end

  @doc "Every counter, or nil when nobody has ever played, so the client can show its empty state."
  def read_all do
    %{rows: rows} = Repo.query!("SELECT name, value FROM statistics")
    stored = Map.new(rows, fn [name, value] -> {name, value} end)
    stats = Map.new(Statistics.fields(), &{&1, Map.get(stored, Atom.to_string(&1), 0)})

    if stats.total_players == 0, do: nil, else: stats
  end
end
