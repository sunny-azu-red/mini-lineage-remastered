defmodule MiniLineage.CharacterLog do
  @moduledoc """
  Everything a run did, in order: the fights, and the deeds around them. Its own table because it
  grows without limit and the character's document is rewritten whole on every save. An entry
  belongs to its character for good, so no second life inherits the first one's.
  """
  import Ecto.Query

  alias MiniLineage.CharacterLog.Entry
  alias MiniLineage.Repo

  # Named rather than derived from the row: the narrative comes back out of the database, and every
  # atom it turns into is one this module names itself.
  @narrative_keys ~w(crit_line kill_line deflection_line outcome_line ambush_line fight_prompt next_move)a

  # Whitelisted here and not in the database, so a new kind is a line of Elixir, not a migration.
  @kinds ~w(fight start purchase level_up cheat ending buff debuff)

  defmodule Entry do
    @moduledoc false
    use Ecto.Schema

    @timestamps_opts [type: :utc_datetime_usec, updated_at: false]
    schema "character_log" do
      field :character_id, :string
      field :kind, :string
      field :narrative, :map

      timestamps()
    end
  end

  # One page of the Chronicle. Smaller in the browser suites, so they can reach a second page.
  @window Application.compile_env(:mini_lineage, :chronicle_page, 25)

  @doc "How many entries a page holds, and so what a refresh opens on."
  def window, do: @window

  @doc """
  The row a fight produces: its lines and nothing else. Built rather than written, so the caller can
  save it in the character's own transaction.
  """
  def row(character_id, %{narrative: narrative, at: at}) do
    %Entry{
      character_id: character_id,
      kind: "fight",
      narrative: Map.new(@narrative_keys, &{Atom.to_string(&1), Map.get(narrative, &1)}),
      inserted_at: at
    }
  end

  @doc """
  The most recent FIGHT, as the battle screen renders it; nil before the first. Filtered on kind
  because `Server.init/1` rebuilds that screen from it.
  """
  def last_for(character_id) do
    Entry
    |> where([e], e.character_id == ^character_id and e.kind == "fight")
    |> order_by([e], desc: e.id)
    |> limit(1)
    |> Repo.one()
    |> to_battle()
  end

  @doc "A built row as `insert_all` wants it: no struct meta, and no id to claim."
  def params(%Entry{} = e), do: e |> Map.from_struct() |> Map.drop([:__meta__, :id])

  @doc """
  The row a deed produces: one sentence, its pronouns still open, stamped when it happened.
  """
  def event(character_id, kind, line, at) when kind in @kinds do
    %Entry{
      character_id: character_id,
      kind: kind,
      narrative: %{"line" => line},
      inserted_at: at
    }
  end

  @doc """
  The `limit` entries before `cursor` (the newest when nil), newest first, and whether older ones
  remain. Numbered by counting the run's rows in the same statement, which holds only because
  nothing is ever deleted from a run's log.
  """
  def page(character_id, cursor \\ nil, limit \\ @window) do
    held = Entry |> where([e], e.character_id == ^character_id) |> older_than(cursor)

    rows =
      held
      |> order_by([e], desc: e.id)
      |> limit(^(limit + 1))
      |> select([e], {e, subquery(select(held, [e], count()))})
      |> Repo.all()

    entries =
      rows
      |> Enum.take(limit)
      |> Enum.with_index(fn {e, count}, i -> to_entry(e, count - i) end)

    {entries, length(rows) > limit}
  end

  defp older_than(query, nil), do: query
  defp older_than(query, cursor), do: where(query, [e], e.id < ^cursor)

  @doc """
  Everything written after `cursor`, newest first, numbered on from `above`, the cursor entry's
  number. A keyset, so an append never walks or counts the rows a reader already holds.
  """
  def since(character_id, cursor, above) do
    Entry
    |> where([e], e.character_id == ^character_id and e.id > ^cursor)
    |> order_by([e], asc: e.id)
    |> Repo.all()
    |> Enum.with_index(fn e, i -> to_entry(e, above + i + 1) end)
    |> Enum.reverse()
  end

  # A fight keeps the shape the battle screen knows; everything else is one line, told apart by
  # `kind`. Only an ambush draws an ambush line.
  defp to_entry(%Entry{kind: "fight"} = e, number) do
    battle = to_battle(e)

    Map.merge(battle, %{
      id: e.id,
      number: number,
      kind: "fight",
      ambushed: battle.narrative.ambush_line != nil
    })
  end

  defp to_entry(%Entry{} = e, number),
    do: %{id: e.id, number: number, kind: e.kind, at: e.inserted_at, line: e.narrative["line"]}

  defp to_battle(nil), do: nil

  defp to_battle(%Entry{} = e) do
    %{
      narrative: Map.new(@narrative_keys, &{&1, Map.get(e.narrative, Atom.to_string(&1))}),
      at: e.inserted_at
    }
  end
end
