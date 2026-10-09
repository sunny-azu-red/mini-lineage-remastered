defmodule MiniLineage.Characters.Store do
  @moduledoc """
  Persistence for characters, and the only place that knows the state is stored as JSON. `id` is
  public and permanent; `session_id` is the cookie's secret, and a run nobody comes back to gives it up.
  """
  import Ecto.Query

  alias MiniLineage.Characters.{Record, Serde}
  alias MiniLineage.Game.Player
  alias MiniLineage.Repo

  # No fallback: config.exs sets it for every environment, and a default here could only disagree.
  @ttl_hours Application.compile_env!(:mini_lineage, :character_ttl_hours)

  @doc "A fresh public character id. Opaque."
  def new_id, do: token()

  @doc "A fresh session id. Opaque, and it is what the session cookie carries."
  def new_session_id, do: token()

  defp token, do: Base.url_encode64(:crypto.strong_rand_bytes(18), padding: false)

  @doc """
  The character this browser is playing, as `{id, player}`, or nil before it has saved anything.
  Never finds a retired run: retiring clears the session it looks for.
  """
  def load_by_session(nil), do: nil

  def load_by_session(session_id) do
    case Repo.one(from r in Record, where: r.session_id == ^session_id, select: {r.id, r.state}) do
      nil -> nil
      {id, state} -> {id, Serde.from_map(state)}
    end
  end

  def save(id, session_id, %Player{} = player) do
    upsert(id, session_id, player)

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

  def delete(id), do: Repo.delete_all(from r in Record, where: r.id == ^id)

  @doc """
  Takes the session off runs untouched for #{@ttl_hours}h, the cookie's own sliding window, which
  leaves the row behind and no browser able to reach it. Nothing is deleted. Returns how many were retired.
  """
  def retire_idle do
    cutoff = DateTime.add(DateTime.utc_now(), -@ttl_hours * 3600, :second)
    idle = from r in Record, where: not is_nil(r.session_id) and r.updated_at < ^cutoff

    {retired, _} = Repo.update_all(idle, set: [session_id: nil])

    retired
  end

  def ttl_hours, do: @ttl_hours
end
