#!/usr/bin/env bash
# Empties the walkthrough's board so a run starts from nothing.
#
# Without this a local database keeps every character an earlier run buried, the top of the board
# fills with them, and a freshly created character can no longer rank — a failure about the game
# that is really about leftovers. CI gets this for free from a new database each run.
set -euo pipefail
cd "$(dirname "$0")/.."
if [ -f ./env.sh ]; then
  # shellcheck disable=SC1091
  source ./env.sh
fi
export MIX_ENV=e2e

# The guard is the point: `highscores` also exists in the database people actually play on, and
# this script must be incapable of reaching it. It compares against what .env names rather than
# looking for a "_test" in the name — with its own file the throwaway database can sit on another
# server entirely, so the suffix had stopped meaning anything.
mix run --no-start -e '
  {:ok, _} = Application.ensure_all_started(:myxql)
  config = Application.get_env(:mini_lineage, MiniLineage.Repo)
  database = config[:database]

  # .env, read directly: runtime.exs has already put .env.test into the environment by now, so
  # System.get_env can no longer say what the real game connects to.
  played_on =
    case File.read(".env") do
      {:ok, contents} ->
        contents
        |> String.split("\n")
        |> Enum.map(&String.trim/1)
        |> Enum.reject(&(&1 == "" or String.starts_with?(&1, "#")))
        |> Enum.flat_map(fn line ->
          case String.split(line, "=", parts: 2) do
            [k, v] -> [{String.trim(k), v |> String.split(~r/\s+#/, parts: 2) |> hd() |> String.trim()}]
            _ -> []
          end
        end)
        |> Map.new()

      _ ->
        %{}
    end

  same_database? =
    database == played_on["DB_DATABASE"] and
      to_string(config[:hostname]) == played_on["DB_HOST"] and
      to_string(config[:port]) == played_on["DB_PORT"]

  if same_database? do
    IO.puts(:stderr, "refusing to reset \"#{database}\" on #{config[:hostname]}: .env names it as the database you play on")
    System.halt(1)
  end

  {:ok, conn} = MyXQL.start_link(Keyword.drop(config, [:pool, :pool_size, :adapter]))
  # DELETE, child first, rather than TRUNCATE: a table a foreign key points at cannot be
  # truncated, and this order is the same one Postgres would need.
  for table <- ~w(battle_log highscores characters),
      do: MyXQL.query!(conn, "DELETE FROM #{table}")
  IO.puts("reset #{database}: battle_log, highscores, characters")
' >/dev/null
