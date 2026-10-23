defmodule MiniLineage.Characters.Store do
  @moduledoc """
  Persistence for characters, and the only place that knows the state is stored as JSON. `id` is
  public and permanent; `session_id` is the cookie's secret, and a run nobody comes back to gives it up.
  """
  import Ecto.Query

  alias MiniLineage.Characters.{Encounter, Item, Record, Serde}
  alias MiniLineage.Game.{Player, Rules}
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
      {id, state} -> {id, %{Serde.from_map(state) | items: items(id)}}
    end
  end

  # In the order they were picked up, which is the order the inventory lists them.
  defp items(id) do
    Repo.all(
      from i in Item,
        where: i.character_id == ^id,
        order_by: [asc: i.inserted_at, asc: i.id],
        select: %{id: i.id, name: i.name, equipped: i.equipped, count: i.count}
    )
    # An item the game no longer has is left behind, not handed to a lookup that would raise on it.
    |> Enum.filter(&Rules.item?(&1.name))
  end

  @doc """
  Writes the character, with `items?` its inventory too, and the fight it has just fought, in one
  transaction, so a purchase can never be written without the Adena it cost, nor a fight without
  what it paid.
  """
  def save(id, session_id, %Player{} = player, items?) do
    Repo.transaction(fn ->
      upsert(id, session_id, player)
      if items?, do: sync_items(id, player.items)
      if player.encounter, do: Repo.insert!(%Encounter{character_id: id, fight: player.encounter})
    end)

    :ok
  end

  @doc """
  Rules §20: the last fight a character fought on a ground, as its hunt told it, or nil. The log is
  the game's own markup, written by nobody else.
  """
  def last_fight(id, ground) do
    Repo.one(
      from e in Encounter,
        where: e.character_id == ^id and e.ground == ^ground,
        order_by: [desc: e.id],
        limit: 1,
        select: e.fight
    )
    |> fight()
  end

  defp fight(nil), do: nil

  defp fight(%{} = stored),
    do: %{
      log:
        for(
          entry <- stored["log"] || [],
          do: %{
            kind: entry["kind"],
            head: entry["head"],
            standing: entry["standing"],
            line: entry["line"]
          }
        ),
      text: stored["text"],
      outcome: outcome(stored["outcome"]),
      levelled: stored["levelled"]
    }

  defp outcome("victory"), do: :victory
  defp outcome("defeat"), do: :defeat
  defp outcome(_escaped), do: :escaped

  # Whatever the process no longer holds goes; whatever it holds is written as it stands.
  defp sync_items(id, items) do
    ids = Enum.map(items, & &1.id)
    Repo.delete_all(from i in Item, where: i.character_id == ^id and i.id not in ^ids)
    now = DateTime.utc_now()

    rows =
      items
      |> Enum.with_index()
      |> Enum.map(fn {item, n} ->
        # Microseconds apart, so the order they were picked up survives a shared timestamp.
        %{
          id: item.id,
          character_id: id,
          name: item.name,
          equipped: item.equipped,
          count: Map.get(item, :count, 1),
          inserted_at: DateTime.add(now, n, :microsecond)
        }
      end)

    Repo.insert_all(Item, rows,
      on_conflict: {:replace, [:equipped, :count]},
      conflict_target: :id
    )
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
  Rules §21: a run's last state and the end of its session, in one statement, so no crash between
  two writes can leave a dead run a browser could still load.
  """
  def retire(id, %Player{} = player) do
    now = DateTime.utc_now()
    state = Serde.to_map(player)

    Repo.insert!(
      %Record{id: id, session_id: nil, state: state, inserted_at: now, updated_at: now},
      on_conflict: [set: [state: state, session_id: nil, updated_at: now]],
      conflict_target: :id
    )

    :ok
  end

  @doc "A fresh item id, minted in the process so an item has it before it is written."
  def new_item_id, do: token()

  def delete(id), do: Repo.delete_all(from r in Record, where: r.id == ^id)

  @doc "Notes that a browser opened or closed the run: a look keeps it, as a write does."
  def seen(id),
    do: Repo.update_all(from(r in Record, where: r.id == ^id), set: [seen_at: DateTime.utc_now()])

  @doc """
  Takes the session off runs neither written nor seen for #{@ttl_hours}h, the cookie's own sliding
  window, sparing the public ids in `online`, which leaves the row behind and no browser able to
  reach it. Nothing is deleted. Returns how many were retired.
  """
  def retire_idle(online) do
    cutoff = DateTime.add(DateTime.utc_now(), -@ttl_hours * 3600, :second)
    online = MapSet.to_list(online)

    # GREATEST skips a NULL, so a run never seen counts from its last write.
    idle =
      from r in Record,
        where:
          not is_nil(r.session_id) and r.id not in ^online and
            fragment("GREATEST(?, ?)", r.updated_at, r.seen_at) < ^cutoff

    {retired, _} = Repo.update_all(idle, set: [session_id: nil])

    retired
  end

  def ttl_hours, do: @ttl_hours
end
