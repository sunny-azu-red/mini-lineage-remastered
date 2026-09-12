defmodule MiniLineage.Repo.Migrations.InitialSchema do
  @moduledoc """
  The whole schema, in one migration.

  It replaces four that told the story of getting here: a baseline for tables the Node stack had
  created, a characters table that had to patch its own JSON column afterwards, a battle log, and
  a rewrite of `highscores` that renamed a column and widened a key. None of that history is worth
  carrying into a database that starts empty — and every workaround in it was a MySQL one.
  """
  use Ecto.Migration

  def change do
    # One row per character, the whole mutable state as a single jsonb document — validated on
    # write, and indexable if the board ever needs to sort on a field inside it.
    create table(:characters, primary_key: false) do
      add :id, :string, size: 32, null: false, primary_key: true
      add :state, :map, null: false
      timestamps(type: :timestamptz)
    end

    # The 30-day sweep is the only thing that queries a character by anything but its id.
    create index(:characters, [:updated_at])

    # The board. Genuinely relational: sorted, filtered by race, and limited.
    create table(:highscores) do
      add :name, :string, size: 64, null: false
      add :total_xp, :bigint, null: false
      add :race_id, :integer, null: false
      add :adena, :bigint, null: false
      add :level, :bigint, null: false
      timestamps(type: :timestamptz, updated_at: false)
    end

    # One row per fight. Append-only, so unlike a character it is never rewritten — which is what
    # lets it grow without limit where the character's own document must not.
    create table(:battle_log) do
      # Soft reference on purpose: a character is swept after 30 days and its unclaimed rows go
      # with it, while a claimed row has to outlive the character that earned it.
      add :character_id, :string, size: 32, null: false
      add :highscore_id, references(:highscores, on_delete: :delete_all), null: true

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

      timestamps(type: :timestamptz, updated_at: false)
    end

    # The current life: every read and write this table does while a character is alive. Partial,
    # because the unclaimed rows are the small, hot end of the table and the index holds only them.
    create index(:battle_log, [:character_id],
             where: "highscore_id IS NULL",
             name: :battle_log_current_life_index
           )

    # And everything one board entry immortalised.
    create index(:battle_log, [:highscore_id])

    # Counters, keyed by name. Written by upsert-with-increment, never read-modify-write.
    create table(:statistics, primary_key: false) do
      add :name, :string, size: 64, null: false, primary_key: true
      add :value, :bigint, null: false, default: 0
    end
  end
end
