defmodule MiniLineage.Game.Statistics.Collector do
  @moduledoc """
  Batches the fire-and-forget counters and flushes them as atomic upserts. The reference issued one
  round trip per increment — a single fight fires seven — so they are coalesced over a short window
  instead.

  Writing and telling are separate concerns here. A write is a round trip and is worth batching for
  a minute; a broadcast is microseconds, so the Tome hears about a counter when it MOVES rather than
  when it is written, and keeps its own running totals in memory to say so without a query.
  """
  use GenServer

  import Ecto.Query

  require Logger

  alias MiniLineage.Game.Statistics
  alias MiniLineage.Repo

  # Generous on purpose, and only about durability: increments coalesce by field, so a batch is
  # capped at the number of counters rather than by the wait, and a hard kill loses a minute of
  # lifetime totals. What a reader sees does not wait for this.
  @flush_ms 60_000

  # The same window the board coalesces on, and for the same reason: a fight moves seven counters
  # and a realm at play moves them constantly, so the telling is gathered up rather than stuttered.
  @push_ms 500

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

    {:ok, %{pending: %{}, totals: stored(), push: nil}}
  end

  @impl true
  def handle_info({:increment, field, amount}, state) do
    state = %{
      state
      | pending: Map.update(state.pending, field, amount, &(&1 + amount)),
        totals: Map.update(state.totals, field, amount, &(&1 + amount))
    }

    {:noreply, arm(state)}
  end

  def handle_info(:push, state) do
    Phoenix.PubSub.broadcast(MiniLineage.PubSub, @topic, {:statistics, view(state.totals)})

    {:noreply, %{state | push: nil}}
  end

  def handle_info(:flush, state) do
    schedule()

    {:noreply, write(state)}
  end

  @impl true
  def handle_call(:flush, _from, state), do: {:reply, :ok, write(state)}

  def handle_call(:pending, _from, state), do: {:reply, state.pending, state}

  @impl true
  def terminate(_reason, state), do: write(state)

  defp schedule, do: Process.send_after(self(), :flush, @flush_ms)

  # An open window is never restarted, or a realm at play would defer its own telling for ever.
  defp arm(%{push: nil} = state),
    do: %{state | push: Process.send_after(self(), :push, @push_ms)}

  defp arm(state), do: state

  # Drains the buffer into ONE statement. Never raises — a counter is not worth this process, and
  # its death would take the buffer too. A failed batch is re-queued by field, so the buffer stays
  # bounded however long an outage runs; `totals` already counted it and is left alone.
  defp write(%{pending: pending} = state) when map_size(pending) == 0, do: state

  defp write(state) do
    batch = Enum.reject(state.pending, fn {_field, amount} -> amount == 0 end)

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

      %{state | pending: %{}}
    rescue
      error -> %{state | pending: requeue(batch, error)}
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

    view(stored())
  end

  defp stored do
    rows = Map.new(Repo.all(from s in "statistics", select: {s.name, s.value}))

    Map.new(Statistics.fields(), &{&1, Map.get(rows, Atom.to_string(&1), 0)})
  end

  defp view(totals), do: if(totals.total_players == 0, do: nil, else: totals)
end
