defmodule MiniLineage.Repo.Migrations.BoardColumns do
  @moduledoc "The Halls rank runs, so what they sort and filter on becomes columns over the document."
  use Ecto.Migration

  def change do
    # Generated, so the board cannot drift from the document and no code writes them. STORED is
    # explicit: PG18 defaults to VIRTUAL, which cannot be indexed.
    alter table(:characters) do
      add :name, :text, generated: "ALWAYS AS (state->>'name') STORED"
      add :race_id, :integer, generated: "ALWAYS AS ((state->>'race_id')::integer) STORED"
      add :total_xp, :bigint, generated: "ALWAYS AS ((state->>'experience')::bigint) STORED"
      add :adena, :bigint, generated: "ALWAYS AS ((state->>'adena')::bigint) STORED"

      # Documents written before death existed carry no key, and are alive.
      add :dead, :boolean,
        generated: "ALWAYS AS (COALESCE((state->>'dead')::boolean, false)) STORED"
    end

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
  end
end
