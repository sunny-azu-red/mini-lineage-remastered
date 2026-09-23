defmodule MiniLineage.SchemaTest do
  @moduledoc """
  The indexes the game cannot go without.

  Named because one went missing silently: dropping a column drops any partial index whose
  predicate mentions it, which is how `character_log` lost its only useful index and started scanning
  the whole table for every new character.

  A query-plan assertion would be truer, but Postgres rightly prefers a sequential scan over the
  few rows a test inserts, so it would pass either way.
  """
  use MiniLineage.DataCase, async: false

  # {table, columns that must be indexed together, in order}
  @required [
    # The last fight of a run, and all of them in order.
    {"character_log", ["character_id", "id"]},
    # The board, and the board filtered to one lineage.
    {"characters", ["total_xp", "adena"]},
    {"characters", ["race_id", "total_xp", "adena"]},
    # A browser finding the character it is playing, on every mount.
    {"characters", ["session_id"]},
    # The hourly retirement.
    {"characters", ["updated_at"]}
  ]

  for {table, columns} <- @required do
    test "#{table} is indexed on #{Enum.join(columns, ", ")}" do
      table = unquote(table)
      columns = unquote(columns)

      definitions =
        Repo.query!(
          "SELECT indexdef FROM pg_indexes WHERE schemaname='public' AND tablename=$1",
          [
            table
          ]
        ).rows
        |> Enum.map(&hd/1)

      assert Enum.any?(definitions, &covers?(&1, columns)),
             """
             no index on #{table} (#{Enum.join(columns, ", ")}).

             If a migration dropped a column, check whether it took an index with it — a partial
             index goes when the column in its WHERE goes.

             #{Enum.join(definitions, "\n")}
             """
    end
  end

  # The columns must appear in this order and as the leading columns, which is what makes the index
  # usable for a query that filters and sorts on them in that order.
  defp covers?(definition, columns) do
    case Regex.run(~r/\(([^)]*)\)/, definition) do
      [_, inside] ->
        indexed =
          inside
          |> String.split(",")
          |> Enum.map(&(&1 |> String.trim() |> String.replace(~r/ (DESC|ASC).*$/, "")))

        Enum.take(indexed, length(columns)) == columns

      _ ->
        false
    end
  end
end
