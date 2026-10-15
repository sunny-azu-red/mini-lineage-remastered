defmodule MiniLineage.Repo.Migrations.SquireDagger do
  @moduledoc """
  Rules §23: the kit's Dagger is the Squire's Dagger now. A row under a name the game no longer has
  is dropped on load and deleted on the next save, so the carried ones are renamed.
  """
  use Ecto.Migration

  def change do
    execute(
      "UPDATE items SET name = 'Squire''s Dagger' WHERE name = 'Dagger'",
      "UPDATE items SET name = 'Dagger' WHERE name = 'Squire''s Dagger'"
    )
  end
end
