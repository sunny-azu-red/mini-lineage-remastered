defmodule MiniLineage.Repo.Migrations.InitialSchema do
  @moduledoc "The whole schema, in one migration, against an empty database."
  use Ecto.Migration

  def change do
    create table(:characters, primary_key: false) do
      # `id` is public; `session_id` is the cookie's secret, given up when the run is retired.
      add :id, :string, size: 32, null: false, primary_key: true
      add :session_id, :string, size: 32, null: true

      # One character is one document, owned by its process and only ever read whole.
      add :state, :map, null: false

      timestamps(type: :timestamptz)
    end

    # Partial: retired runs have no session, and NULLs would otherwise be half the index.
    create unique_index(:characters, [:session_id], where: "session_id IS NOT NULL")
  end
end
