defmodule MiniLineage.Repo.Migrations.CharacterItems do
  @moduledoc "What a character carries grows with play, so it is a table of its own, not the document."
  use Ecto.Migration

  def change do
    create table(:items, primary_key: false) do
      # Minted by the character's process, so an item has its id before it is ever written.
      add :id, :string, size: 32, null: false, primary_key: true

      add :character_id, references(:characters, type: :string, on_delete: :delete_all),
        size: 32,
        null: false

      # A rules §23 item by name, held to the data file by its own test.
      add :name, :text, null: false
      add :equipped, :boolean, null: false, default: false

      timestamps(type: :timestamptz, updated_at: false)
    end

    # A character's items, read whole when its process starts.
    create index(:items, [:character_id])
  end
end
