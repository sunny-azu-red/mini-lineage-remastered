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

  alias MiniLineage.Characters
  alias MiniLineage.Characters.Record
  alias MiniLineage.Game.{Constants, Math}
  alias MiniLineage.Repo

  @topic "board"
  # Long enough to swallow a flurry of fights, short enough that a climb still feels live.
  @coalesce_ms 500

  def start_link(_opts), do: GenServer.start_link(__MODULE__, :ok, name: __MODULE__)

  @doc "Subscribe to pushed refreshes. The message is `{:board, boards}`, keyed by race filter."
  def subscribe, do: Phoenix.PubSub.subscribe(MiniLineage.PubSub, @topic)

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

  @doc "One run by its public id, for its own page. Disqualified runs still render their own."
  def entry(id) do
    Record
    |> where([r], r.id == ^id and not is_nil(r.race_id))
    |> row()
    |> Repo.one()
    |> decorate()
  end

  @impl true
  def init(:ok) do
    {:ok, %{boards: compute(), timer: nil, pending: :none}}
  end

  @impl true
  def handle_call(:current, _from, state), do: {:reply, state.boards, state}

  @impl true
  def handle_info(:changed, state), do: {:noreply, arm(state, :write)}
  def handle_info(:presence, state), do: {:noreply, arm(state, :presence)}

  # Every refresh pushes, whichever kind it was. Watching a run climb and a dot come on are the
  # same screen, and only one of the two needs the database.
  def handle_info(:refresh, state) do
    boards = if state.pending == :write, do: compute(), else: remark(state.boards)
    Phoenix.PubSub.broadcast(MiniLineage.PubSub, @topic, {:board, boards})

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
    overall = top(nil)

    medals =
      overall |> Enum.take(3) |> Enum.with_index(1) |> Map.new(&{elem(&1, 0).id, elem(&1, 1)})

    online = Characters.online()

    Constants.races()
    |> Map.new(&{&1.id, mark(top(&1.id), medals, online)})
    |> Map.put(nil, mark(overall, medals, online))
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

  defp top(race_id) do
    ranked()
    |> then(&if race_id, do: where(&1, [r], r.race_id == ^race_id), else: &1)
    |> order_by([r], desc: r.total_xp, desc: r.adena, asc: r.inserted_at, desc: r.id)
    |> limit(^Constants.highscores_limit())
    |> row()
    |> Repo.all()
    |> Enum.map(&decorate/1)
  end

  # A run is ranked once it has chosen a race. A coward's and a cheat's never is — their own page
  # still renders, which is why this is a board rule rather than a deletion.
  defp ranked, do: from(r in Record, where: not is_nil(r.race_id) and r.disqualified == false)

  # Selected into a plain map, never a %Record{}: the schema struct carries `session_id`, and an
  # entry that has the key at all is one `Repo.all(Record)` away from carrying the secret with it.
  # `active` is the one thing said about the session — whether there is one, never what it is.
  # The date is `last_action_at` and not `updated_at`, which moves for things nobody did: a tick
  # the backstop flushed, a tab closing, a run being started over.
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
      last_action_at: r.last_action_at,
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
