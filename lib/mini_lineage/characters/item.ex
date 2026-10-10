defmodule MiniLineage.Characters.Item do
  @moduledoc """
  One thing a character carries, stored in its own table because an inventory grows with play. The
  character's process owns the list; this is only how it is written down.
  """
  use Ecto.Schema

  @primary_key {:id, :string, autogenerate: false}
  schema "items" do
    field :character_id, :string
    field :name, :string
    field :equipped, :boolean, default: false

    timestamps(type: :utc_datetime_usec, updated_at: false)
  end
end
