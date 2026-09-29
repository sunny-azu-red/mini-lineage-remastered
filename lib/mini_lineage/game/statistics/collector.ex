defmodule MiniLineage.Game.Statistics.Collector do
  @moduledoc """
  Batches the fire-and-forget counters and flushes them as atomic upserts. Writing and telling are
  separate: a write is a round trip and is batched for a minute, while the Tome hears about a
  counter when it MOVES, from running totals kept in memory.
  """
  use GenServer

  import Ecto.Query

  require Logger

  alias MiniLineage.Game.Statistics
  alias MiniLineage.Repo

  # Only about durability: increments coalesce by field, so a batch is capped at the number of
  # counters, and a hard kill loses a minute of totals. What a reader sees does not wait for this.
  @flush_ms 60_000

  # The board's window, for the same reason: a fight moves seven counters at once.
  @push_ms 500

  @topic "statistics"

  def start_link(_opts), do: GenServer.start_link(__MODULE__, %{}, name: __MODULE__)

  @doc "Subscribe to the archives. The message is `{:statistics, totals}`, or nil before anyone has played."
  def subscribe, do: Phoenix.PubSub.subscribe(MiniLineage.PubSub, @topic)

  def unsubscribe, do: Phoenix.PubSub.unsubscribe(MiniLineage.PubSub, @topic)

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
  def handle_call(:totals, _from, state), do: {:reply, view(state.totals), state}

  def handle_call(:pending, _from, state), do: {:reply, state.pending, state}

  @impl true
  def terminate(_reason, state), do: write(state)

  defp schedule, do: Process.send_after(self(), :flush, @flush_ms)

  # An open window is never restarted, or a realm at play would defer its own telling for ever.
  defp arm(%{push: nil} = state),
    do: %{state | push: Process.send_after(self(), :push, @push_ms)}

  defp arm(state), do: state

  # ONE statement, and never raises: this process dying would take the buffer. A failed batch is
  # re-queued by field, so the buffer stays bounded; `totals` already counted it.
  defp write(%{pending: pending} = state) when map_size(pending) == 0, do: state

  defp write(state) do
    batch = Enum.reject(state.pending, fn {_field, amount} -> amount == 0 end)

    entries =
      Enum.map(batch, fn {field, amount} -> %{name: Atom.to_string(field), value: amount} end)

    # `rescue`, not an error tuple: `insert_all` raises, as does a value the driver cannot encode.
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
    # Stored plus pending, so a new player reads their own birth with no write or query.
    case Process.whereis(__MODULE__) do
      nil -> view(stored())
      pid -> GenServer.call(pid, :totals)
    end
  end

  defp stored do
    rows = Map.new(Repo.all(from s in "statistics", select: {s.name, s.value}))

    Map.new(Statistics.fields(), &{&1, Map.get(rows, Atom.to_string(&1), 0)})
  end

  defp view(totals), do: if(totals.total_players == 0, do: nil, else: totals)
end
