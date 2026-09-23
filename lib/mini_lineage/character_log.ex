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

  defmodule Entry do
    @moduledoc false
    use Ecto.Schema

    @timestamps_opts [type: :utc_datetime_usec, updated_at: false]
    schema "character_log" do
      field :character_id, :string

      field :enemies_killed, :integer
      field :hp_lost, :integer
      field :damage_blocked, :integer
      field :xp_gained, :integer
      field :adena_gained, :integer
      field :is_critical, :boolean
      field :is_level_up, :boolean
      field :ambushed, :boolean
      field :died, :boolean

      field :kind, :string
      field :narrative, :map
      field :sound, :string

      timestamps()
    end
  end

  # What a record opens with. The reader watches it grow from here, and a refresh comes back to the
  # same window rather than to wherever it had grown to.
  @window 100

  @doc """
  The row a fight produces. Built here rather than written, so the caller can put it in the same
  transaction as the character it belongs to — a logged fight the character does not remember is
  worse than no log at all.
  """
  def row(character_id, %{outcome: outcome, narrative: narrative} = battle) do
    %Entry{
      character_id: character_id,
      enemies_killed: outcome.enemies_killed,
      hp_lost: outcome.hp_lost,
      damage_blocked: outcome.damage_blocked,
      xp_gained: outcome.xp_gained,
      adena_gained: outcome.adena_gained,
      is_critical: outcome.is_critical,
      is_level_up: outcome.is_level_up,
      kind: "fight",
      ambushed: battle.ambushed == true,
      died: battle.died == true,
      narrative: Map.new(@narrative_keys, &{Atom.to_string(&1), Map.get(narrative, &1)}),
      sound: battle.sound,
      inserted_at: battle.at
    }
  end

  @doc """
  The most recent FIGHT, as the shape the battle screen renders. Nil before the first one.

  The kind is the whole point: `Server.init/1` rebuilds the battle screen from this, so without it
  a player who last bought a blade reconnects to a battle report with no lines and no numbers.
  """
  def last_for(character_id) do
    Entry
    |> where([e], e.character_id == ^character_id and e.kind == "fight")
    |> order_by([e], desc: e.id)
    |> limit(1)
    |> Repo.one()
    |> to_battle()
  end

  @doc """
  The last `limit` fights of one run, oldest first within that window.

  Capped, not paged: the whole history of a long run went through the socket on every page load to
  fill a 260px box. `Record.road/1` above the panel already tells a reader when the road opened,
  which is what the entries beyond the window would have said.
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
  Everything written after `cursor`, oldest first, for a record being read as it happens.

  A keyset and not an offset: an offset walks every row it skips, so a run that has fought five
  hundred times pays for five hundred to append one. The table is append-only, so what a reader
  already holds can never change.
  """
  def since(character_id, cursor) do
    Entry
    |> where([e], e.character_id == ^character_id and e.id > ^cursor)
    |> order_by([e], asc: e.id)
    |> Repo.all()
    |> Enum.map(&to_entry/1)
  end

  defp to_entry(%Entry{} = e), do: e |> to_battle() |> Map.put(:id, e.id)

  defp to_battle(nil), do: nil

  defp to_battle(%Entry{} = e) do
    %{
      narrative: Map.new(@narrative_keys, &{&1, Map.get(e.narrative, Atom.to_string(&1))}),
      outcome: %{
        enemies_killed: e.enemies_killed,
        hp_lost: e.hp_lost,
        damage_blocked: e.damage_blocked,
        xp_gained: e.xp_gained,
        adena_gained: e.adena_gained,
        is_critical: e.is_critical,
        is_level_up: e.is_level_up
      },
      ambushed: e.ambushed,
      died: e.died,
      sound: e.sound,
      at: e.inserted_at
    }
  end
end
