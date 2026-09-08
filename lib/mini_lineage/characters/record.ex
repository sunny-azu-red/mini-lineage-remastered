defmodule MiniLineage.Characters.Record do
  @moduledoc "The stored row. Three columns: an opaque id, the whole state as JSON, and timestamps."
  use Ecto.Schema

  @primary_key {:id, :string, autogenerate: false}
  schema "characters" do
    field :state, :map
    timestamps(type: :utc_datetime_usec)
  end
end
