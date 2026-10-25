defmodule MiniLineage.Board do
  @moduledoc """
  The Halls: every run that has chosen a race, best first, living, fallen or missing. A view of
  `characters`, not a table. This process coalesces refreshes into one recomputation per window
  and pushes it; a change of presence pushes too, and reads nothing, since it moves no ranking.
  """
  use GenServer

  import Ecto.Query

  require Logger

  alias MiniLineage.Characters
  alias MiniLineage.Characters.Record
  alias MiniLineage.Game.{Constants, Math}
  alias MiniLineage.Repo

  @topic "board"
  # Long enough to swallow a flurry of hunts, short enough that a climb still feels live.
  @coalesce_ms 500
  @limit 25

  def start_link(_opts), do: GenServer.start_link(__MODULE__, :ok, name: __MODULE__)

  @doc "Subscribe to pushed refreshes. The message is `{:board, boards}`, keyed by race filter."
  def subscribe, do: Phoenix.PubSub.subscribe(MiniLineage.PubSub, @topic)

  def unsubscribe, do: Phoenix.PubSub.unsubscribe(MiniLineage.PubSub, @topic)

  @doc "How many runs each board lists."
  def limit, do: @limit

  @doc "Tell the board a character was written. Cheap and asynchronous: never blocks the writer."
  def character_changed, do: signal(:changed)

  @doc """
  Tell the board who is holding a character open has changed. Costs no query: presence is the one
  thing on a row that moves without a write, and it comes from the registry.
  """
  def presence_changed, do: signal(:presence)

  defp signal(message) do
    if pid = Process.whereis(__MODULE__), do: send(pid, message)

    :ok
  end

  @doc """
  Every board as it stands, for a viewer who has just arrived. Computed in the caller when the
  process is not running, so tests read a board without a timer querying outside their sandbox.
  """
  def current do
    case Process.whereis(__MODULE__) do
      nil -> compute()
      pid -> GenServer.call(pid, :current)
    end
  end

  @impl true
  def init(:ok), do: {:ok, %{boards: compute(), timer: nil, pending: :none}}

  @impl true
  def handle_call(:current, _from, state), do: {:reply, state.boards, state}

  @impl true
  def handle_info(:changed, state), do: {:noreply, arm(state, :write)}
  def handle_info(:presence, state), do: {:noreply, arm(state, :presence)}

  # Either kind of refresh pushes, but only a board that moved: a climb and a dot coming on are the
  # same screen, only one of the two needs the database, and a write off the board moves neither.
  def handle_info(:refresh, state) do
    boards = if state.pending == :write, do: compute(), else: remark(state.boards)

    moved? = boards != state.boards
    if moved?, do: Phoenix.PubSub.broadcast(MiniLineage.PubSub, @topic, {:board, boards})

    Logger.debug(fn ->
      "[BOARD] #{if moved?, do: "Pushed", else: "Unchanged"} | #{state.pending}"
    end)

    {:noreply, %{state | boards: boards, timer: nil, pending: :none}}
  end

  # A write anywhere in the window wins it: it may have moved a row that a re-stamp would leave
  # standing. An existing timer is never restarted, or a busy game would defer its own refresh.
  defp arm(state, kind) do
    %{
      state
      | pending: if(state.pending == :write or kind == :write, do: :write, else: :presence),
        timer: state.timer || Process.send_after(self(), :refresh, @coalesce_ms)
    }
  end

  # One list per filter the screen offers, so a viewer on "Elves" is served by the same push as a
  # viewer on "All" rather than querying for themselves.
  defp compute do
    filters = [nil | Enum.map(Constants.races(), & &1.id)]
    boards = boards(filters)
    overall = Map.get(boards, nil, [])

    medals =
      overall |> Enum.take(3) |> Enum.with_index(1) |> Map.new(&{elem(&1, 0).id, elem(&1, 1)})

    online = Characters.online()

    Map.new(filters, &{&1, mark(Map.get(boards, &1, []), medals, online)})
  end

  # Three in the whole game wear a medal: a lineage's board shows one only where the full one does.
  defp mark(rows, medals, online) do
    Enum.map(rows, fn row ->
      %{row | medal: Map.get(medals, row.id), online: MapSet.member?(online, row.id)}
    end)
  end

  # Nothing was written, so no ranking moved: only the dots are re-stamped, and nothing is queried.
  defp remark(boards) do
    online = Characters.online()

    Map.new(boards, fn {filter, rows} ->
      {filter, Enum.map(rows, &%{&1 | online: MapSet.member?(online, &1.id)})}
    end)
  end

  # Every board in ONE statement, because a round trip costs more than the query does.
  defp boards(filters) do
    [first | rest] = Enum.map(filters, &from(t in subquery(top(&1)), select: t))

    from(t in subquery(Enum.reduce(rest, first, &union_all(&2, ^&1))))
    |> order_by([t], asc: t.board)
    |> by_rank()
    |> Repo.all()
    |> Enum.map(&decorate/1)
    |> Enum.group_by(& &1.board, &Map.delete(&1, :board))
  end

  # A subquery per filter, because Ecto hangs a branch's ORDER BY and LIMIT on the whole union.
  # SQL promises no order out of the union either, which is why `boards/1` sorts again.
  defp top(race_id) do
    from(r in Record, where: not is_nil(r.race_id))
    |> then(&if race_id, do: where(&1, [r], r.race_id == ^race_id), else: &1)
    |> by_rank()
    |> limit(@limit)
    |> row()
    |> select_merge(%{board: type(^race_id, :integer)})
  end

  # Rules §21: by EXP, which is by level and then EXP, since a level is an EXP threshold.
  defp by_rank(query),
    do: order_by(query, [r], desc: r.total_xp, desc: r.adena, asc: r.inserted_at, desc: r.id)

  # A plain map, never a %Record{}: the struct carries `session_id`, and an entry holding the key
  # at all is one `Repo.all(Record)` from carrying the secret. `active` says whether there is a
  # session, never what it is.
  defp row(query) do
    select(query, [r], %{
      id: r.id,
      name: r.name,
      race_id: r.race_id,
      total_xp: r.total_xp,
      adena: r.adena,
      dead: r.dead,
      died_at: r.died_at,
      # What the idle retirement counts from: GREATEST skips a NULL, as it does there.
      last_seen: type(fragment("GREATEST(?, ?)", r.updated_at, r.seen_at), :utc_datetime_usec),
      inserted_at: r.inserted_at,
      active: not is_nil(r.session_id)
    })
  end

  # Level comes from the same function the character screen uses, which is why no column stores it.
  # A sighting is kept only once the run is missing, when it can no longer move: a living run's
  # moves with every write, and the board would push and sweep its row for nothing.
  defp decorate(%{last_seen: last_seen} = entry) do
    entry
    |> Map.delete(:last_seen)
    |> Map.merge(%{
      level: Math.level_for_xp(entry.total_xp),
      missing_since: if(entry.dead or entry.active, do: nil, else: last_seen),
      medal: nil,
      online: false
    })
  end
end
