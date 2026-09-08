defmodule MiniLineage.Repo.Migrations.CreateCharacters do
  @moduledoc """
  One row per character, with the whole mutable state as a single JSON document.

  The previous design gave every PlayerState field its own column, so adding a field meant a
  migration. Only `updated_at` is ever queried on — it drives the 24h sweep. The old table held
  development data from an abandoned branch and is dropped outright.
  """
  use Ecto.Migration

  def up do
    drop_if_exists table(:characters)

    create table(:characters, primary_key: false) do
      add :id, :string, size: 32, null: false, primary_key: true
      add :state, :map, null: false
      timestamps(type: :utc_datetime_usec)
    end

    # Ecto's MyXQL adapter maps :map to longtext; we want MySQL to validate the document.
    execute "ALTER TABLE characters MODIFY COLUMN state json NOT NULL"

    create index(:characters, [:updated_at])
  end

  def down do
    drop table(:characters)
  end
end
