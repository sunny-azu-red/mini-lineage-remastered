defmodule MiniLineage.Repo.Migrations.BaselineExistingTables do
  @moduledoc """
  Marks the tables the Node stack already created and filled. `create_if_not_exists` is a no-op
  against the live database and reproduces the schema on a fresh one, so nothing here can touch
  the real `highscores` or `statistics` rows.

  One statement per call throughout — MyXQL rejects multi-statement queries, and hand-rolled SQL
  splitting is what produced silently-broken statements in the Node migrator.
  """
  use Ecto.Migration

  def change do
    create_if_not_exists table(:highscores) do
      add :name, :string, size: 64, null: false
      add :total_xp, :bigint, null: false
      add :race_id, :integer, null: false
      add :adena, :bigint, null: false
      add :level, :bigint, null: false
      add :created, :naive_datetime, null: false
    end

    create_if_not_exists table(:statistics, primary_key: false) do
      add :name, :string, size: 64, null: false, primary_key: true
      add :value, :bigint, null: false, default: 0
    end
  end
end
