defmodule MiniLineage.Repo.Migrations.ARunFindsItsOwnFights do
  @moduledoc """
  Gives `battle_log` back an index on the character.

  It had one, as a partial index whose predicate named `highscore_id`. Dropping that column took
  the index with it — silently, because a dropped column takes every index that depends on it —
  and left the one table designed to grow without limit with nothing but its primary key.

  `(character_id, id)` serves both questions the table is asked: the last fight of a run, and all
  of them in order. Measured at 30,000 rows, the worst case was a character with NO fights, which
  is every new one: 2.1ms scanning the whole primary key backwards for a match that is not there.
  """
  use Ecto.Migration

  def change do
    create index(:battle_log, [:character_id, :id])
  end
end
