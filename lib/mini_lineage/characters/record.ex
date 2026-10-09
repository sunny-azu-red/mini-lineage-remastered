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

    timestamps(type: :utc_datetime_usec)
  end
end
