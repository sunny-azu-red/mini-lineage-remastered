defmodule MiniLineage.Repo.Migrations.InitialSchema do
  @moduledoc """
  The whole schema, in one migration, against an empty database. The generated columns are
  declared inline because Postgres appends an ALTER'd column after the timestamps.
  """
  use Ecto.Migration

  def change do
    create table(:characters, primary_key: false) do
      # `id` is public; `session_id` is the cookie's secret, given up when the run is retired.
      add :id, :string, size: 32, null: false, primary_key: true
      add :session_id, :string, size: 32, null: true

      # One character is one document, owned by its process and only ever read whole.
      add :state, :map, null: false

      # The Halls sort and filter on these, so they are generated and no code writes them. STORED
      # is explicit: PG18 defaults to VIRTUAL, which cannot be indexed.
      add :name, :text, generated: "ALWAYS AS (state->>'name') STORED"
      add :race_id, :integer, generated: "ALWAYS AS ((state->>'race_id')::integer) STORED"
      add :total_xp, :bigint, generated: "ALWAYS AS ((state->>'experience')::bigint) STORED"
      add :adena, :bigint, generated: "ALWAYS AS ((state->>'adena')::bigint) STORED"

      # Documents written before death existed carry no key, and are alive.
      add :dead, :boolean,
        generated: "ALWAYS AS (COALESCE((state->>'dead')::boolean, false)) STORED"

      timestamps(type: :timestamptz)
    end

    # Partial: retired runs have no session, and NULLs would otherwise be half the index.
    create unique_index(:characters, [:session_id], where: "session_id IS NOT NULL")

    # The whole ORDER BY is in the key, so no sort follows the scan. A visitor has no race and is
    # never written, but the predicate keeps the index honest if one ever were.
    create index(:characters, ["total_xp DESC", "adena DESC", "inserted_at ASC", "id DESC"],
             where: "race_id IS NOT NULL",
             name: :characters_board_index
           )

    create index(
             :characters,
             ["race_id", "total_xp DESC", "adena DESC", "inserted_at ASC", "id DESC"],
             where: "race_id IS NOT NULL",
             name: :characters_board_by_race_index
           )

    # What a character carries grows with play, so it is a table of its own, not the document.
    create table(:items, primary_key: false) do
      # Minted by the character's process, so an item has its id before it is ever written.
      add :id, :string, size: 32, null: false, primary_key: true

      add :character_id, references(:characters, type: :string, on_delete: :delete_all),
        size: 32,
        null: false

      # A rules §23 item by name, held to the data file by its own test.
      add :name, :text, null: false
      add :equipped, :boolean, null: false, default: false

      # Rules §26: a potion stacks, one row holding how many; every other item is one of itself.
      add :count, :integer, null: false, default: 1

      timestamps(type: :timestamptz, updated_at: false)
    end

    # A character's items, read whole when its process starts.
    create index(:items, [:character_id])
  end
end
