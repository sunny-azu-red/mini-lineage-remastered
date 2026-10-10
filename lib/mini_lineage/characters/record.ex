defmodule MiniLineage.Characters.Record do
  @moduledoc """
  The stored row. `id` is public; `session_id` is the cookie's secret, so a character's public id is
  never a way to play as them. The character itself is the `state` document.
  """
  use Ecto.Schema

  @primary_key {:id, :string, autogenerate: false}
  schema "characters" do
    field :session_id, :string
    field :state, :map

    # Generated from `state` for the Halls; Postgres writes them, never the application.
    field :name, :string, writable: :never
    field :race_id, :integer, writable: :never
    field :total_xp, :integer, writable: :never
    field :adena, :integer, writable: :never
    field :dead, :boolean, writable: :never

    timestamps(type: :utc_datetime_usec)
  end
end
