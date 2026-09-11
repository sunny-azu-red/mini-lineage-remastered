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
export DB_DATABASE="${DB_DATABASE_TEST:-lineage_remastered_test}"
export MIX_ENV=e2e

# The guard is the point: `highscores` also exists in the database people actually play on, and
# this script must be incapable of reaching it. Refuses anything not named for a test.
mix run --no-start -e '
  {:ok, _} = Application.ensure_all_started(:myxql)
  config = Application.get_env(:mini_lineage, MiniLineage.Repo)
  database = config[:database]

  unless String.ends_with?(database, "_test") do
    IO.puts(:stderr, "refusing to reset \"#{database}\": only a _test database may be emptied")
    System.halt(1)
  end

  {:ok, conn} = MyXQL.start_link(Keyword.drop(config, [:pool, :pool_size, :adapter]))
  # DELETE, child first, rather than TRUNCATE: a table a foreign key points at cannot be
  # truncated, and this order is the same one Postgres would need.
  for table <- ~w(battle_log highscores characters),
      do: MyXQL.query!(conn, "DELETE FROM #{table}")
  IO.puts("reset #{database}: battle_log, highscores, characters")
' >/dev/null
