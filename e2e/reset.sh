#!/usr/bin/env bash
# Empties the browser suites' database so a run starts from nothing. CI gets a new one anyway.
set -euo pipefail
cd "$(dirname "$0")/.."
if [ -f ./env.sh ]; then
  # shellcheck disable=SC1091
  source ./env.sh
fi
export MIX_ENV=e2e

# The guard is the point: this table exists in the database people play on too. It compares
# against what .env names, not a "_test" suffix.
mix run --no-start -e '
  {:ok, _} = Application.ensure_all_started(:postgrex)
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

  {:ok, conn} = Postgrex.start_link(Keyword.drop(config, [:pool, :pool_size, :adapter]))
  # CASCADE is deliberately NOT used: naming the table keeps this incapable of reaching another.
  Postgrex.query!(conn, "TRUNCATE characters", [])
  IO.puts("reset #{database}: characters")
' >/dev/null
