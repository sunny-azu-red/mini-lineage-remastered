defmodule MiniLineage.Characters.Store do
  @moduledoc "Persistence for characters. The only place that knows the state is stored as JSON."
  import Ecto.Query

  alias MiniLineage.Characters.{Record, Serde}
  alias MiniLineage.Game.Player
  alias MiniLineage.Repo

  @ttl_hours 24

  @doc "A fresh, unstarted character id. Opaque — it is what the session cookie carries."
  def new_id, do: Base.url_encode64(:crypto.strong_rand_bytes(18), padding: false)

  def load(id) do
    case Repo.get(Record, id) do
      nil -> nil
      %Record{state: state} -> Serde.from_map(state)
    end
  end

  # MySQL has no conflict target — `on_conflict` compiles to ON DUPLICATE KEY UPDATE, which keys
  # off the primary key on its own.
  def save(id, %Player{} = player) do
    now = DateTime.utc_now()
    state = Serde.to_map(player)

    Repo.insert!(%Record{id: id, state: state, inserted_at: now, updated_at: now},
      on_conflict: [set: [state: state, updated_at: now]]
    )

    :ok
  end

  def delete(id), do: Repo.delete_all(from r in Record, where: r.id == ^id)

  @doc "Drops characters untouched for #{@ttl_hours}h, matching the reference's session lifetime."
  def sweep_expired do
    cutoff = DateTime.add(DateTime.utc_now(), -@ttl_hours * 3600, :second)
    {count, _} = Repo.delete_all(from r in Record, where: r.updated_at < ^cutoff)

    count
  end
end
