defmodule MiniLineage.Repo.Migrations.CreateEncounters do
  use Ecto.Migration

  def change do
    # Rules §20: every fight a run fought grows with play, so it is a table of its own.
    create table(:encounters) do
      add :character_id, references(:characters, type: :string, on_delete: :delete_all),
        size: 32,
        null: false

      # The fight log, what it came to and where, read back whole and never sorted on.
      add :fight, :map, null: false

      # A ground's page draws the last fight fought there. STORED: PG18 defaults to VIRTUAL, which
      # cannot be indexed.
      add :ground, :text, generated: "ALWAYS AS (fight->>'ground') STORED"

      timestamps(type: :timestamptz, updated_at: false)
    end

    create index(:encounters, ["character_id", "ground", "id DESC"])
  end
end
