defmodule MiniLineage.BattleLog do
  @moduledoc """
  Every fight a character has had, in order.

  It lives here rather than in the character's document because it grows without limit, and the
  document is rewritten whole on every save — a history kept inside it would put the write cost
  back, and more of it with every fight.

  A row is unclaimed until the run is written to the board, at which point it is stamped with that
  entry and outlives the character. Unclaimed rows belong to the character's current life and go
  when that life ends without a legacy, or when the character is swept.
  """
  import Ecto.Query

  alias MiniLineage.BattleLog.Entry
  alias MiniLineage.Repo

  # Named rather than derived from the row: the narrative comes back out of the database, and every
  # atom it turns into is one this module names itself.
  @narrative_keys ~w(crit_line kill_line deflection_line outcome_line ambush_line fight_prompt next_move)a

  defmodule Entry do
    @moduledoc false
    use Ecto.Schema

    @timestamps_opts [type: :utc_datetime_usec, updated_at: false]
    schema "battle_log" do
      field :character_id, :string
      field :highscore_id, :integer

      field :enemies_killed, :integer
      field :hp_lost, :integer
      field :damage_blocked, :integer
      field :xp_gained, :integer
      field :adena_gained, :integer
      field :is_critical, :boolean
      field :is_level_up, :boolean
      field :ambushed, :boolean
      field :died, :boolean

      field :narrative, :map
      field :sound, :string

      timestamps()
    end
  end

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
      ambushed: battle.ambushed == true,
      died: battle.died == true,
      narrative: Map.new(@narrative_keys, &{Atom.to_string(&1), Map.get(narrative, &1)}),
      sound: battle.sound
    }
  end

  @doc "The most recent fight, as the shape the battle screen renders. Nil before the first one."
  def last_for(character_id) do
    Entry
    |> where([e], e.character_id == ^character_id)
    |> order_by([e], desc: e.id)
    |> limit(1)
    |> Repo.one()
    |> to_battle()
  end

  @doc "Claims this character's unclaimed fights for a board entry, so they outlive the character."
  def claim(character_id, highscore_id) do
    {count, _} =
      Entry
      |> where([e], e.character_id == ^character_id and is_nil(e.highscore_id))
      |> Repo.update_all(set: [highscore_id: highscore_id])

    count
  end

  @doc "Drops a life that ended without a legacy, so the next one does not inherit its fights."
  def discard_unclaimed(character_id) do
    {count, _} =
      Entry
      |> where([e], e.character_id == ^character_id and is_nil(e.highscore_id))
      |> Repo.delete_all()

    count
  end

  @doc "Unclaimed rows whose character no longer exists. Runs with the character sweep."
  def sweep_orphaned do
    characters = from(c in "characters", select: c.id)

    {count, _} =
      Entry
      |> where([e], is_nil(e.highscore_id) and e.character_id not in subquery(characters))
      |> Repo.delete_all()

    count
  end

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
      sound: e.sound
    }
  end
end
