defmodule MiniLineage.Characters.Encounter do
  @moduledoc """
  One fight a character fought (rules §20), stored in its own table because a run's fights grow
  with play. Written once, in the character's transaction, and never changed.
  """
  use Ecto.Schema

  schema "encounters" do
    field :character_id, :string
    field :fight, :map

    # Generated from `fight`; Postgres writes it, never the application.
    field :ground, :string, writable: :never

    timestamps(type: :utc_datetime_usec, updated_at: false)
  end
end
