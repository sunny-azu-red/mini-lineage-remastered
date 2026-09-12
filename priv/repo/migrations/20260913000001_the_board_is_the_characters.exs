defmodule MiniLineage.Repo.Migrations.TheBoardIsTheCharacters do
  @moduledoc """
  The Halls of Champions stop being a table of their own and become a view of the characters.

  A run is on the board from the moment it picks a race, and stays there when it ends — so the
  sweep can no longer be the board's memory, and the id can no longer be the session cookie.

  Nothing ages out of the table now: an abandoned run is retired onto the board rather than
  deleted, and only its session is taken. The foreign key below is therefore integrity alone, and
  its cascade fires for one case only — a visitor who never chose a race.
  """
  use Ecto.Migration

  def up do
    # The referencing column first: the table it points at cannot be dropped while it stands.
    alter table(:battle_log) do
      remove :highscore_id
    end

    drop table(:highscores)

    # Safe now, and only now: a dead character is never swept, so a claimed fight can no longer
    # outlive its character. This is what the soft reference was standing in for.
    alter table(:battle_log) do
      modify :character_id, references(:characters, type: :string, on_delete: :delete_all),
        from: {:string, null: false},
        null: false
    end

    alter table(:characters) do
      # The cookie moves off the primary key: `id` is public now, and a public id that is also a
      # session would let anyone paste a champion's link into their own cookie and play as them.
      add :session_id, :string, size: 32, null: true
    end

    # One statement per execute. Generated columns are STORED explicitly — under PG18 the default
    # became VIRTUAL, which cannot be indexed, and the board would silently seq-scan.
    execute "ALTER TABLE characters ADD COLUMN name text GENERATED ALWAYS AS (state->>'name') STORED"

    execute "ALTER TABLE characters ADD COLUMN race_id integer GENERATED ALWAYS AS ((state->>'race_id')::integer) STORED"

    execute "ALTER TABLE characters ADD COLUMN total_xp bigint GENERATED ALWAYS AS ((state->>'experience')::bigint) STORED"

    execute "ALTER TABLE characters ADD COLUMN adena bigint GENERATED ALWAYS AS ((state->>'adena')::bigint) STORED"

    execute "ALTER TABLE characters ADD COLUMN dead boolean GENERATED ALWAYS AS ((state->>'dead')::boolean) STORED"

    execute """
    ALTER TABLE characters ADD COLUMN disqualified boolean
      GENERATED ALWAYS AS (((state->>'coward')::boolean) OR ((state->>'cheated')::boolean)) STORED
    """

    create unique_index(:characters, [:session_id])

    # The board: started, not disqualified, best first. Partial because an unstarted visitor and a
    # disqualified run are never ranked, and they are the rows the index should not carry.
    execute """
    CREATE INDEX characters_board_index ON characters
      (total_xp DESC, adena DESC, inserted_at ASC, id DESC)
      WHERE race_id IS NOT NULL AND NOT disqualified
    """

    execute """
    CREATE INDEX characters_board_by_race_index ON characters
      (race_id, total_xp DESC, adena DESC, inserted_at ASC, id DESC)
      WHERE race_id IS NOT NULL AND NOT disqualified
    """

    # Nothing is deleted for being old any more — an abandoned run is retired onto the board like
    # any other. What ages out is the session, so that is what this index has to find.
    drop index(:characters, [:updated_at])

    execute "CREATE INDEX characters_idle_index ON characters (updated_at) WHERE session_id IS NOT NULL"
  end

  def down do
    execute "DROP INDEX characters_idle_index"
    create index(:characters, [:updated_at])
    execute "DROP INDEX characters_board_by_race_index"
    execute "DROP INDEX characters_board_index"
    drop unique_index(:characters, [:session_id])

    for column <- ~w(disqualified dead adena total_xp race_id name session_id) do
      execute "ALTER TABLE characters DROP COLUMN #{column}"
    end

    drop constraint(:battle_log, "battle_log_character_id_fkey")

    create table(:highscores) do
      add :name, :string, size: 64, null: false
      add :total_xp, :bigint, null: false
      add :race_id, :integer, null: false
      add :adena, :bigint, null: false
      add :level, :bigint, null: false
      timestamps(type: :timestamptz, updated_at: false)
    end

    alter table(:battle_log) do
      add :highscore_id, references(:highscores, on_delete: :delete_all), null: true
    end

    create index(:battle_log, [:highscore_id])
  end
end
