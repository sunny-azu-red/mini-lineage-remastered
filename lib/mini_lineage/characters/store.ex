defmodule MiniLineage.Characters.Store do
  @moduledoc """
  Persistence for characters. The only place that knows the state is stored as JSON.

  Two identities: `id` is public and permanent, `session_id` is the secret in the cookie. A run
  that has ended gives up its session, which both takes it off the browser and puts it out of the
  retirement's reach.
  """
  import Ecto.Query

  alias MiniLineage.CharacterLog
  alias MiniLineage.Characters.{Record, Serde}
  alias MiniLineage.Game.Player
  alias MiniLineage.Repo

  @ttl_hours Application.compile_env(:mini_lineage, :character_ttl_hours, 24)

  @doc "A fresh public character id. Opaque, and it appears in every board link."
  def new_id, do: token()

  @doc "A fresh session id. Opaque, and it is what the session cookie carries."
  def new_session_id, do: token()

  defp token, do: Base.url_encode64(:crypto.strong_rand_bytes(18), padding: false)

  @doc """
  The character this browser is playing, as `{id, player}`, or nil before it has saved anything.
  Only ever finds a run still in progress — archiving clears the session it looks for.
  """
  def load_by_session(nil), do: nil

  def load_by_session(session_id) do
    case Repo.one(from r in Record, where: r.session_id == ^session_id, select: {r.id, r.state}) do
      nil -> nil
      {id, state} -> {id, Serde.from_map(state)}
    end
  end

  def save(id, session_id, player, rows \\ [])

  # No log row to stay consistent with, so no transaction. BEGIN and COMMIT are two more round trips,
  # and at ~0.8ms each on this network they cost more than the write they were wrapping.
  def save(id, session_id, %Player{} = player, []) do
    upsert(id, session_id, player)

    :ok
  end

  # One transaction: a log row written without its character would describe a run whose own totals
  # do not include it.
  def save(id, session_id, %Player{} = player, rows) do
    Repo.transaction(fn ->
      upsert(id, session_id, player)
      Repo.insert_all(CharacterLog.Entry, Enum.map(rows, &CharacterLog.params/1))
    end)

    :ok
  end

  # The conflict target is named, so a second unique index added later cannot quietly change which
  # collision this updates on.
  defp upsert(id, session_id, player) do
    now = DateTime.utc_now()
    state = Serde.to_map(player)

    Repo.insert!(
      %Record{id: id, session_id: session_id, state: state, inserted_at: now, updated_at: now},
      on_conflict: [set: [state: state, updated_at: now]],
      conflict_target: :id
    )
  end

  @doc """
  Ends a run: the row keeps its id, its stats and its fights, and gives up its session. It is off
  this browser and out of the sweep's reach from here on.
  """
  def archive(session_id) do
    {count, _} =
      Repo.update_all(
        from(r in Record, where: r.session_id == ^session_id),
        set: [session_id: nil]
      )

    count
  end

  def delete(id), do: Repo.delete_all(from r in Record, where: r.id == ^id)

  @doc """
  Retires runs untouched for #{@ttl_hours}h — the cookie's own window: both slide, the
  cookie re-issued on every visit and `updated_at` moving on every save. A retired run keeps its place and its fights and gives up only its session,
  which is what makes it MISSING rather than dead. Nothing is deleted. Returns how many were.
  """
  def retire_idle do
    cutoff = DateTime.add(DateTime.utc_now(), -@ttl_hours * 3600, :second)
    idle = from r in Record, where: not is_nil(r.session_id) and r.updated_at < ^cutoff

    {retired, _} = Repo.update_all(idle, set: [session_id: nil])

    retired
  end

  def ttl_hours, do: @ttl_hours
end
