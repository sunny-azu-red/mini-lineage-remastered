defmodule MiniLineage.Board do
  @moduledoc """
  The Halls of Champions: every run that has chosen a race, best first, alive or finished. A view
  of `characters`, not a table, so a run appears the moment it starts and keeps its place when it
  ends. This process coalesces the refresh into one recomputation per window and pushes it, rather
  than letting every viewer re-query for every write.
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
  def character_changed do
    if pid = Process.whereis(__MODULE__), do: send(pid, :changed)

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
    {:ok, %{boards: compute(), timer: nil}}
  end

  @impl true
  def handle_call(:current, _from, state), do: {:reply, state.boards, state}

  @impl true
  def handle_info(:changed, %{timer: nil} = state),
    do: {:noreply, %{state | timer: Process.send_after(self(), :refresh, @coalesce_ms)}}

  # Already waiting to refresh: the write it is waiting for has simply been joined by another.
  def handle_info(:changed, state), do: {:noreply, state}

  def handle_info(:refresh, state) do
    boards = compute()
    Phoenix.PubSub.broadcast(MiniLineage.PubSub, @topic, {:board, boards})

    {:noreply, %{state | boards: boards, timer: nil}}
  end

  # One list per filter the screen offers, so a viewer on "Elves" is served by the same push as a
  # viewer on "All" rather than querying for themselves.
  defp compute do
    overall = top(nil)

    medals =
      overall |> Enum.take(3) |> Enum.with_index(1) |> Map.new(&{elem(&1, 0).id, elem(&1, 1)})

    online = Characters.online()

    Enum.map(Constants.races(), & &1.id)
    |> Map.new(&{&1, mark(top(&1), medals, online)})
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
      updated_at: r.updated_at,
      active: not is_nil(r.session_id)
    })
  end

  defp decorate(nil), do: nil

  # Level is derived from experience by the same function the character screen uses, so the two can
  # never disagree — and it is why there is no generated column for it.
  # Every row has the same shape whether it came from a board or a single lookup. A missing key is
  # a 500, and the board is served from a cache that can outlive a deploy of the template.
  defp decorate(entry),
    do: Map.merge(entry, %{level: Math.level_for_xp(entry.total_xp), medal: nil, online: false})
end
