defmodule MiniLineage.Game.Statistics.Collector do
  @moduledoc """
  Batches the fire-and-forget counters and flushes them as atomic upserts. The reference issued one
  round trip per increment — a single fight fires seven — so they are coalesced over a short window
  instead. Nothing reads these back mid-fight, so the delay is invisible.
  """
  use GenServer

  import Ecto.Query

  require Logger

  alias MiniLineage.Game.Statistics
  alias MiniLineage.Repo

  # Generous on purpose. `read_all/0` drains the buffer before it queries, so the archives are
  # never stale however long this is; increments coalesce by field, so a batch is capped at the
  # number of counters rather than by the wait; and a hard kill loses a minute of lifetime totals.
  @flush_ms 60_000

  @topic "statistics"

  def start_link(_opts), do: GenServer.start_link(__MODULE__, %{}, name: __MODULE__)

  @doc "Subscribe to the archives. The message is `{:statistics, totals}`, or nil before anyone has played."
  def subscribe, do: Phoenix.PubSub.subscribe(MiniLineage.PubSub, @topic)

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

    entries =
      Enum.map(batch, fn {field, amount} -> %{name: Atom.to_string(field), value: amount} end)

    # `rescue` rather than an error tuple: `insert_all` raises, and so does a value the driver
    # cannot encode. A raise here would take the process down and the buffer with it — which is
    # the very thing re-queueing exists to prevent.
    try do
      Repo.insert_all("statistics", entries,
        conflict_target: :name,
        on_conflict: from(s in "statistics", update: [inc: [value: fragment("EXCLUDED.value")]])
      )

      # Only once the counters are actually in: the Tome reads them back, so a push that beat the
      # write would tell a reader about totals the database does not have yet.
      publish()

      %{}
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

    totals()
  end

  defp totals do
    stored = Map.new(Repo.all(from s in "statistics", select: {s.name, s.value}))
    stats = Map.new(Statistics.fields(), &{&1, Map.get(stored, Atom.to_string(&1), 0)})

    if stats.total_players == 0, do: nil, else: stats
  end

  # One read per flush, however many people are reading the Tome — and `totals/0` rather than
  # `read_all/0`, which would call this process from inside itself and wait for its own reply.
  defp publish do
    Phoenix.PubSub.broadcast(MiniLineage.PubSub, @topic, {:statistics, totals()})
  rescue
    _ -> :ok
  end
end
