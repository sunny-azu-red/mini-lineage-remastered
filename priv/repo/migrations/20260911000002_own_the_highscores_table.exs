defmodule MiniLineage.Repo.Migrations.OwnTheHighscoresTable do
  @moduledoc """
  Brings `highscores` in line with the rest of the schema.

  `created` becomes `inserted_at` with microsecond precision, matching `characters` and
  `battle_log`; the values already were UTC, they simply were not labelled, so nothing converts.
  The key widens to bigint so a fight can point at it, and that reference becomes a real foreign
  key — deleting a board entry now takes the run it immortalised with it.

  One statement per execute, and the id is widened in raw SQL on purpose: `modify :id, :bigint`
  drops AUTO_INCREMENT, which would leave the table unable to take another legacy.
  """
  use Ecto.Migration

  def up do
    execute "ALTER TABLE highscores MODIFY COLUMN id BIGINT NOT NULL AUTO_INCREMENT"

    rename table(:highscores), :created, to: :inserted_at

    alter table(:highscores) do
      modify :inserted_at, :utc_datetime_usec, null: false
    end

    # A dangling reference would fail the constraint below. There should be none; this is here so
    # the migration does not depend on that being true.
    execute """
    UPDATE battle_log SET highscore_id = NULL
    WHERE highscore_id IS NOT NULL AND highscore_id NOT IN (SELECT id FROM highscores)
    """

    alter table(:battle_log) do
      modify :highscore_id, references(:highscores, type: :bigint, on_delete: :delete_all)
    end
  end

  def down do
    drop constraint(:battle_log, "battle_log_highscore_id_fkey")

    alter table(:highscores) do
      modify :inserted_at, :naive_datetime, null: false
    end

    rename table(:highscores), :inserted_at, to: :created
    execute "ALTER TABLE highscores MODIFY COLUMN id INT NOT NULL AUTO_INCREMENT"
  end
end
