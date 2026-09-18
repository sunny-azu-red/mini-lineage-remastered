defmodule MiniLineage.Repo.Migrations.InitialSchema do
  @moduledoc """
  The whole schema, in one migration. The database starts empty, so there is no history to carry.

  Column order is deliberate and is why the generated columns are declared here rather than added
  afterwards: Postgres appends an ALTER'd column to the end of the table, which would have put the
  timestamps in the middle.
  """
  use Ecto.Migration

  def change do
    create table(:characters, primary_key: false) do
      # Two identities. `id` is public and appears in every board link; `session_id` is the secret
      # the cookie carries, and a run that has ended gives it up — which both takes it off the
      # browser and marks it as something the retirement must leave alone.
      add :id, :string, size: 32, null: false, primary_key: true
      add :session_id, :string, size: 32, null: true

      add :state, :map, null: false

      # Derived by Postgres from the document on every write, so the board sorts relationally and
      # cannot drift from the character. STORED is explicit: PG18 made the default VIRTUAL, which
      # cannot be indexed, and the board would silently fall back to a sequential scan.
      add :name, :text, generated: "ALWAYS AS (state->>'name') STORED"
      add :race_id, :integer, generated: "ALWAYS AS ((state->>'race_id')::integer) STORED"
      add :total_xp, :bigint, generated: "ALWAYS AS ((state->>'experience')::bigint) STORED"
      add :adena, :bigint, generated: "ALWAYS AS ((state->>'adena')::bigint) STORED"
      add :dead, :boolean, generated: "ALWAYS AS ((state->>'dead')::boolean) STORED"

      add :disqualified, :boolean,
        generated:
          "ALWAYS AS (((state->>'coward')::boolean) OR ((state->>'cheated')::boolean)) STORED"

      # What the Halls date a run by, and not `updated_at`: the row is written for the passage of
      # time too — a regenerating tick the backstop flushes, the last flush as a tab closes — and
      # none of that is something anybody did. Stored as epoch milliseconds the way `combat_until`
      # is, because text::timestamptz is STABLE and Postgres refuses it in a generated column.
      add :last_action_at, :timestamptz,
        generated:
          "ALWAYS AS (to_timestamp(((state->>'last_action_at')::bigint) / 1000.0)) STORED"

      timestamps(type: :timestamptz)
    end

    # Partial: a retired run has no session, and an index entry per NULL is half this index's size
    # once archiving has had time to accumulate. Uniqueness is unaffected — NULLs never collide.
    create unique_index(:characters, [:session_id], where: "session_id IS NOT NULL")

    # The board: started, not disqualified, best first. The sort columns are in the key so the
    # whole ORDER BY is served by the index rather than by a sort afterwards.
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

    # The hourly retirement only ever looks at runs still attached to a browser.
    create index(:characters, [:updated_at],
             where: "session_id IS NOT NULL",
             name: :characters_idle_index
           )

    # One row per fight. Append-only, so unlike a character it is never rewritten — which is what
    # lets it grow without limit where the character's own document must not.
    create table(:battle_log) do
      add :character_id, references(:characters, type: :string, on_delete: :delete_all),
        null: false

      # The rendered lines, so a chronicle never has to re-roll the prose it already told.
      add :narrative, :map, null: false

      add :enemies_killed, :integer, null: false, default: 0
      add :hp_lost, :integer, null: false, default: 0
      add :damage_blocked, :integer, null: false, default: 0
      add :xp_gained, :integer, null: false, default: 0
      add :adena_gained, :integer, null: false, default: 0
      add :is_critical, :boolean, null: false, default: false
      add :is_level_up, :boolean, null: false, default: false
      add :ambushed, :boolean, null: false, default: false
      add :died, :boolean, null: false, default: false
      add :sound, :string, size: 16

      timestamps(type: :timestamptz, updated_at: false)
    end

    # Both questions this table is asked: a run's last fight, and all of them in order. Without it
    # the commonest case — a character with no fights yet — scans the whole table backwards.
    create index(:battle_log, [:character_id, :id])

    # Counters, keyed by name. Written by upsert-with-increment, never read-modify-write.
    create table(:statistics, primary_key: false) do
      add :name, :string, size: 64, null: false, primary_key: true
      add :value, :bigint, null: false, default: 0
    end
  end
end
