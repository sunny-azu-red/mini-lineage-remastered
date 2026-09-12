defmodule MiniLineage.Characters.Store do
  @moduledoc """
  Persistence for characters. The only place that knows the state is stored as JSON.

  A character has two identities. `id` is public and permanent — the board links to it and the
  battle log points at it. `session_id` is the secret in the cookie, and a run that has been
  played to its end gives it up: that is what both detaches it from the browser and marks it as
  something the sweep must never take.
  """
  import Ecto.Query

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
  def load_by_session(session_id) do
    case Repo.one(from r in Record, where: r.session_id == ^session_id) do
      nil -> nil
      %Record{id: id, state: state} -> {id, Serde.from_map(state)}
    end
  end

  @doc "One character by its public id, for a board link. Returns the player, alive or dead."
  def load(id) do
    case Repo.get(Record, id) do
      nil -> nil
      %Record{state: state} -> Serde.from_map(state)
    end
  end

  # The conflict target is named, so a second unique index added later cannot quietly change which
  # collision this updates on.
  def save(id, session_id, %Player{} = player, battles \\ []) do
    now = DateTime.utc_now()
    state = Serde.to_map(player)

    # One transaction: a fight written without the character that fought it would show in the log
    # as a battle its own totals do not include.
    Repo.transaction(fn ->
      Repo.insert!(
        %Record{id: id, session_id: session_id, state: state, inserted_at: now, updated_at: now},
        on_conflict: [set: [state: state, updated_at: now]],
        conflict_target: :id
      )

      Enum.each(battles, &Repo.insert!/1)
    end)

    :ok
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
  Retires runs nobody has touched for #{@ttl_hours}h — the same window the session cookie is issued
  for, so a character is let go exactly when the browser holding it would have forgotten anyway.
  Sliding, because `updated_at` moves on every save: "since you last played", not "since you
  started".

  Retiring is not deleting. An abandoned run has still been played, so it keeps its place on the
  board and its fights, and gives up only its session — which is what stops anyone picking it up.
  Returns `{retired, discarded}`.
  """
  def retire_idle do
    cutoff = DateTime.add(DateTime.utc_now(), -@ttl_hours * 3600, :second)
    idle = from r in Record, where: not is_nil(r.session_id) and r.updated_at < ^cutoff

    # A visitor who never chose a race is nobody: no name, no fights, nothing to rank. That row is
    # the one thing here still worth deleting, and its fights (there are none) cascade with it.
    {discarded, _} = Repo.delete_all(from r in idle, where: is_nil(r.race_id))
    {retired, _} = Repo.update_all(idle, set: [session_id: nil])

    {retired, discarded}
  end

  def ttl_hours, do: @ttl_hours
end
