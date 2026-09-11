defmodule MiniLineage.Repo.Migrations.CreateBattleLog do
  @moduledoc """
  One row per fight. Append-only, so unlike a character it is never rewritten — which is what lets
  it grow without limit where the character's own document must not.

  Structured where it would be aggregated and JSON where it is only ever rendered. Types chosen to
  survive a move to Postgres unchanged: the timestamp is timezone-aware rather than naive, the
  flags are real booleans, and the narrative becomes `jsonb` rather than needing a rewrite.
  """
  use Ecto.Migration

  def change do
    create table(:battle_log) do
      # Soft references, both on purpose. A character is swept after 30 days and its unclaimed
      # rows go with it; a highscore is never deleted, so there is nothing for a constraint here
      # to protect, and leaving it out keeps a table this app did not create out of its schema.
      add :character_id, :string, size: 32, null: false
      add :highscore_id, :bigint, null: true

      add :enemies_killed, :integer, null: false, default: 0
      add :hp_lost, :integer, null: false, default: 0
      add :damage_blocked, :integer, null: false, default: 0
      add :xp_gained, :integer, null: false, default: 0
      add :adena_gained, :integer, null: false, default: 0
      add :is_critical, :boolean, null: false, default: false
      add :is_level_up, :boolean, null: false, default: false
      add :ambushed, :boolean, null: false, default: false
      add :died, :boolean, null: false, default: false

      add :narrative, :map, null: false
      add :sound, :string, size: 16

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    # Both questions this table is asked: a character's current life (highscore_id IS NULL), and
    # everything a board entry immortalised. Under Postgres the first becomes a partial index.
    create index(:battle_log, [:character_id, :highscore_id])
    create index(:battle_log, [:highscore_id])
  end
end
