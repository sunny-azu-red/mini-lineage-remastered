defmodule MiniLineage.CharacterLog do
  @moduledoc """
  Everything a run did, in the order it did it: the fights, and the deeds around them. Its own
  table because it grows without limit and the character's document is rewritten whole on every
  save. An entry belongs to its character for good, so no second life inherits the first one's.
  """
  import Ecto.Query

  alias MiniLineage.CharacterLog.Entry
  alias MiniLineage.Repo

  # Named rather than derived from the row: the narrative comes back out of the database, and every
  # atom it turns into is one this module names itself.
  @narrative_keys ~w(crit_line kill_line deflection_line outcome_line ambush_line fight_prompt next_move)a

  # A fight tells its story in seven lines; every other deed says one thing. Whitelisted here and
  # not in the database, so a new kind is a line of Elixir rather than a migration.
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

  # What a record opens with. The reader watches it grow from here, and a refresh comes back to the
  # same window rather than to wherever it had grown to.
  @window 100

  @doc """
  The row a fight produces: its lines and nothing else, since the lines say everything a reader is
  told. Built rather than written so the caller can save it in the character's own transaction.
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
  Built rather than written, for the same reason `row/2` is.
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
  The last `limit` entries of one run, oldest first. Capped, not paged: the road above the panel
  already says when the run began.
  """
  def recent(character_id, limit \\ @window) do
    Entry
    |> where([e], e.character_id == ^character_id)
    |> order_by([e], desc: e.id)
    |> limit(^limit)
    |> Repo.all()
    |> Enum.reverse()
    |> Enum.map(&to_entry/1)
  end

  @doc """
  Everything written after `cursor`, oldest first. A keyset, not an offset, so appending one entry
  never walks the rows a reader already holds.
  """
  def since(character_id, cursor) do
    Entry
    |> where([e], e.character_id == ^character_id and e.id > ^cursor)
    |> order_by([e], asc: e.id)
    |> Repo.all()
    |> Enum.map(&to_entry/1)
  end

  # What the Chronicle iterates. A fight keeps the shape the battle screen knows; everything else
  # is one line, and the component tells them apart by `kind`. Only an ambush draws an ambush line.
  defp to_entry(%Entry{kind: "fight"} = e) do
    battle = to_battle(e)
    Map.merge(battle, %{id: e.id, kind: "fight", ambushed: battle.narrative.ambush_line != nil})
  end

  defp to_entry(%Entry{} = e),
    do: %{id: e.id, kind: e.kind, at: e.inserted_at, line: e.narrative["line"]}

  defp to_battle(nil), do: nil

  defp to_battle(%Entry{} = e) do
    %{
      narrative: Map.new(@narrative_keys, &{&1, Map.get(e.narrative, Atom.to_string(&1))}),
      at: e.inserted_at
    }
  end
end
