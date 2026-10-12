defmodule MiniLineage.Repo.Migrations.ItemCounts do
  @moduledoc "Rules §26: a potion stacks, one row holding how many; every other item is one of itself."
  use Ecto.Migration

  def change do
    alter table(:items) do
      add :count, :integer, null: false, default: 1
    end
  end
end
