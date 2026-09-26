defmodule MiniLineage.Board do
  @moduledoc """
  The Halls of Champions: every run that has chosen a race, best first, alive or finished. A view
  of `characters`, not a table, so a run appears the moment it starts and keeps its place when it
  ends. This process coalesces the refresh into one recomputation per window and pushes it, rather
  than letting every viewer re-query for every write. A change of presence pushes too, and reads
  nothing — a mount and an unmount are the commonest refreshes of all and neither moves a ranking.
  """
  use GenServer

  import Ecto.Query

  require Logger

  alias MiniLineage.{CharacterLog, Characters}
  alias MiniLineage.Characters.{Record, Serde}
  alias MiniLineage.Game.{Constants, Math}
  alias MiniLineage.Repo

  @topic "board"
  # Long enough to swallow a flurry of fights, short enough that a climb still feels live.
  @coalesce_ms 500

  def start_link(_opts), do: GenServer.start_link(__MODULE__, :ok, name: __MODULE__)

  @doc "Subscribe to pushed refreshes. The message is `{:board, boards}`, keyed by race filter."
  def subscribe, do: Phoenix.PubSub.subscribe(MiniLineage.PubSub, @topic)

  def unsubscribe, do: Phoenix.PubSub.unsubscribe(MiniLineage.PubSub, @topic)

  @doc "Tell the board a character was written. Cheap and asynchronous — never blocks the writer."
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
  process is not running — which is how tests read a board without a timer firing queries at them
  from outside their sandbox.
  """
  def current do
    case Process.whereis(__MODULE__) do
      nil -> compute()
      pid -> GenServer.call(pid, :current)
    end
  end

  @doc """
  One run by its public id, for its own page. Disqualified runs still render their own. With
  `player: true` it carries the character too, read from the same row rather than a second query.
  """
  def entry(id, opts \\ []) do
    from(r in Record, as: :row, where: r.id == ^id and not is_nil(r.race_id))
    |> row()
    |> then(&if(opts[:player], do: select_merge(&1, [r], %{player: r.state}), else: &1))
    |> seen()
    |> Repo.one()
    |> decorate()
    |> hydrate()
  end

  defp hydrate(%{player: state} = entry), do: %{entry | player: Serde.from_map(state)}
  defp hydrate(entry), do: entry

  @impl true
  def init(:ok) do
    {:ok, %{boards: compute(), timer: nil, pending: :none}}
  end

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
      "[BOARD] #{if moved?, do: "Pushed", else: "Unchanged"} | #{state.pending} " <>
        "(#{Characters.online() |> MapSet.size()} online)"
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

  # Three in the whole game wear a medal, so a lineage's own board shows one only where that
  # character would have worn it on the full board too. Presence comes from the registry, so it
  # costs no query and is as live as the push carrying it.
  defp mark(rows, medals, online) do
    Enum.map(rows, fn row ->
      %{row | medal: Map.get(medals, row.id), online: MapSet.member?(online, row.id)}
    end)
  end

  # Who is online, re-stamped onto the rows already held. The rankings cannot have moved — nothing
  # was written — so this is the same board with different dots, and it queries nothing.
  defp remark(boards) do
    online = Characters.online()

    Map.new(boards, fn {filter, rows} ->
      {filter, Enum.map(rows, &%{&1 | online: MapSet.member?(online, &1.id)})}
    end)
  end

  # Every board in ONE statement, because a round trip costs more than the query does.
  defp boards(filters) do
    [first | rest] = Enum.map(filters, &from(t in subquery(top(&1)), select: t))

    from(t in subquery(Enum.reduce(rest, first, &union_all(&2, ^&1))), as: :row)
    |> seen()
    |> order_by([t], asc: t.board)
    |> by_rank()
    |> Repo.all()
    |> Enum.map(&decorate/1)
    |> Enum.group_by(& &1.board, &Map.delete(&1, :board))
  end

  # A subquery per filter, because Ecto hangs a branch's ORDER BY and LIMIT on the whole union.
  # SQL promises no order out of the union either, which is why `boards/1` sorts again.
  defp top(race_id) do
    ranked()
    |> then(&if race_id, do: where(&1, [r], r.race_id == ^race_id), else: &1)
    |> by_rank()
    |> limit(^Constants.highscores_limit())
    |> row()
    |> select_merge(%{board: type(^race_id, :integer)})
  end

  defp by_rank(query),
    do: order_by(query, [r], desc: r.total_xp, desc: r.adena, asc: r.inserted_at, desc: r.id)

  # A run is ranked once it has chosen a race. A coward's and a cheat's never is — their own page
  # still renders, which is why this is a board rule rather than a deletion.
  defp ranked, do: from(r in Record, where: not is_nil(r.race_id) and r.disqualified == false)

  # When a run was last seen is the date of its last entry in the log, read rather than stored, so
  # the Halls and the Chronicle cannot disagree about it. A `LIMIT 1` walk backwards down
  # `(character_id, id)`: 8µs a row, and no deeper for a run that has fought twenty thousand times.
  defp seen(query) do
    last =
      from(l in CharacterLog.Entry,
        where: l.character_id == parent_as(:row).id,
        order_by: [desc: l.id],
        limit: 1,
        select: %{at: l.inserted_at}
      )

    query
    |> join(:left_lateral, [], l in subquery(last), on: true)
    |> select_merge([r, ..., l], %{last_seen_at: coalesce(l.at, r.inserted_at)})
  end

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
      disqualified: r.disqualified,
      inserted_at: r.inserted_at,
      active: not is_nil(r.session_id)
    })
  end

  defp decorate(nil), do: nil

  # Level comes from the same function the character screen uses, which is why no column stores it.
  # `medal` and `online` are defaulted rather than left out: a board and a single lookup must have
  # the same shape, and the cache serving them can outlive a deploy of the template that reads it.
  defp decorate(entry),
    do: Map.merge(entry, %{level: Math.level_for_xp(entry.total_xp), medal: nil, online: false})
end
