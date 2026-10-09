defmodule MiniLineage.SchemaTest do
  @moduledoc """
  The indexes the game cannot go without, named because dropping a column silently drops any
  partial index whose predicate mentions it. A query-plan assertion cannot stand in: Postgres
  rightly prefers a sequential scan over the few rows a test inserts.
  """
  use MiniLineage.DataCase, async: false

  # {table, columns that must be indexed together, in order}
  @required [
    # A browser finding the character it is playing, on every mount; and the hourly retirement,
    # which asks about exactly the runs this holds.
    {"characters", ["session_id"]}
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
