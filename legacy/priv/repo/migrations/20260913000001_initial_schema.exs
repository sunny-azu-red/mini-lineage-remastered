defmodule MiniLineage.Repo.Migrations.InitialSchema do
  @moduledoc """
  The whole schema, in one migration, against an empty database. The generated columns are
  declared inline because Postgres appends an ALTER'd column after the timestamps.
  """
  use Ecto.Migration

  def change do
    create table(:characters, primary_key: false) do
      # `id` is public and goes in board links; `session_id` is the cookie's secret, given up when
      # the run is retired.
      add :id, :string, size: 32, null: false, primary_key: true
      add :session_id, :string, size: 32, null: true

      add :state, :map, null: false

      # Derived from the document so the board cannot drift from it. STORED is explicit: PG18
      # defaults to VIRTUAL, which cannot be indexed.
      add :name, :text, generated: "ALWAYS AS (state->>'name') STORED"
      add :race_id, :integer, generated: "ALWAYS AS ((state->>'race_id')::integer) STORED"
      add :total_xp, :bigint, generated: "ALWAYS AS ((state->>'experience')::bigint) STORED"
      add :adena, :bigint, generated: "ALWAYS AS ((state->>'adena')::bigint) STORED"
      add :dead, :boolean, generated: "ALWAYS AS ((state->>'dead')::boolean) STORED"

      add :disqualified, :boolean, generated: "ALWAYS AS ((state->>'cheated')::boolean) STORED"

      timestamps(type: :timestamptz)
    end

    # Partial: retired runs have no session, and NULLs would otherwise be half the index.
    create unique_index(:characters, [:session_id], where: "session_id IS NOT NULL")

    # The board: the whole ORDER BY is in the key, so no sort follows the scan.
    create index(:characters, ["total_xp DESC", "adena DESC", "inserted_at ASC", "id DESC"],
             where: "race_id IS NOT NULL AND NOT disqualified",
             name: :characters_board_index
           )

    create index(
             :characters,
             ["race_id", "total_xp DESC", "adena DESC", "inserted_at ASC", "id DESC"],
             where: "race_id IS NOT NULL AND NOT disqualified",
             name: :characters_board_by_race_index
           )

    # No index on `updated_at`: it moves on every save, which would defeat HOT updates. The
    # retirement walks the session index instead.

    # One row per thing a run did. Append-only, so it may grow where the document must not.
    create table(:character_log) do
      add :character_id, references(:characters, type: :string, on_delete: :delete_all),
        null: false

      # No CHECK or enum, so a new kind is not a migration: `CharacterLog`'s `@kinds` is the list.
      add :kind, :string, size: 16, null: false

      # The rendered lines, never re-rolled. The totals live in `statistics`.
      add :narrative, :map, null: false

      timestamps(type: :timestamptz, updated_at: false)
    end

    # Serves a run's last fight, its newest entries, and everything after a cursor.
    create index(:character_log, [:character_id, :id])

    # Counters, keyed by name. Written by upsert-with-increment, never read-modify-write.
    create table(:statistics, primary_key: false) do
      add :name, :string, size: 64, null: false, primary_key: true
      add :value, :bigint, null: false, default: 0
    end
  end
end
