defmodule MiniLineage.Game.Statistics.Collector do
  @moduledoc """
  Batches the fire-and-forget counters and flushes them as atomic upserts. The reference issued one
  round trip per increment — a single fight fires seven — so they are coalesced over a short window
  instead. Nothing reads these back mid-fight, so the delay is invisible.
  """
  use GenServer

  require Logger

  alias MiniLineage.Game.Statistics
  alias MiniLineage.Repo

  @flush_ms 1_000

  def start_link(_opts), do: GenServer.start_link(__MODULE__, %{}, name: __MODULE__)

  @doc "Writes everything pending now. For tests and shutdown."
  def flush, do: GenServer.call(__MODULE__, :flush)

  @doc "What is still owed to the database. For the console, and for asserting a re-queue."
  def pending, do: GenServer.call(__MODULE__, :pending)

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
    schedule()

    {:noreply, write(pending)}
  end

  @impl true
  def handle_call(:flush, _from, pending), do: {:reply, :ok, write(pending)}

  def handle_call(:pending, _from, pending), do: {:reply, pending, pending}

  @impl true
  def terminate(_reason, pending), do: write(pending)

  defp schedule, do: Process.send_after(self(), :flush, @flush_ms)

  # Drains the buffer into ONE statement and returns whatever is still owed. Never raises — a
  # counter is not worth this process, and its death would take the buffer too. A failed batch is
  # re-queued by field, so the buffer stays bounded however long an outage runs.
  defp write(pending) when map_size(pending) == 0, do: pending

  defp write(pending) do
    batch = Enum.reject(pending, fn {_field, amount} -> amount == 0 end)

    values = Enum.map_join(batch, ", ", fn _ -> "(?, ?)" end)
    params = Enum.flat_map(batch, fn {field, amount} -> [Atom.to_string(field), amount] end)

    sql =
      "INSERT INTO statistics (name, value) VALUES #{values} " <>
        "ON DUPLICATE KEY UPDATE value = value + VALUES(value)"

    # `rescue` as well as the error tuple: a value the driver cannot even encode RAISES rather
    # than returning one, and a raise here would take the process down and the buffer with it —
    # which is the very thing re-queueing exists to prevent.
    try do
      case Repo.query(sql, params) do
        {:ok, _result} -> %{}
        {:error, error} -> requeue(batch, error)
      end
    rescue
      error -> requeue(batch, error)
    end
  end

  defp requeue(batch, error) do
    Logger.error(
      "📊 statistics flush failed, #{length(batch)} counter(s) re-queued: #{Exception.message(error)}"
    )

    Map.new(batch)
  end

  @doc "Every counter, or nil when nobody has ever played, so the client can show its empty state."
  def read_all do
    # Read-your-writes: a brand-new player's own total_players must not still be sitting in the
    # buffer, or the archives read as empty to the very player who just filled them.
    if Process.whereis(__MODULE__), do: flush()

    %{rows: rows} = Repo.query!("SELECT name, value FROM statistics")
    stored = Map.new(rows, fn [name, value] -> {name, value} end)
    stats = Map.new(Statistics.fields(), &{&1, Map.get(stored, Atom.to_string(&1), 0)})

    if stats.total_players == 0, do: nil, else: stats
  end
end
