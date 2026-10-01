# The board statement and a chronicle page, timed through Ecto on the dev database:
#
#     MIX_BUILD_PATH=_build/bench mix run --no-start bench/board.exs
#
# Its own build, because the dev server loads from `_build/dev`: a `mix run` compiling there while
# the server reloads corrupts the beams it is reading, and its character processes crash.
#
# Each run is saved under its branch, or under BENCH_TAG when set, and every other saved run is
# loaded beside it: measure `main` then the branch, or BENCH_TAG=before then the change. Only the
# Repo and the Registry are started: without the Board process `Board.current/0` computes in the
# caller, which is the query under test.
alias MiniLineage.{Board, CharacterLog, Repo}

Logger.configure(level: :warning)
{:ok, _} = Application.ensure_all_started([:postgrex, :ecto_sql])
{:ok, _} = Repo.start_link()
{:ok, _} = Registry.start_link(keys: :unique, name: MiniLineage.Characters.Registry)

%{rows: [[longest, entries, oldest_page]]} =
  Repo.query!("""
  SELECT character_id, count(*), (array_agg(id ORDER BY id))[least(count(*), 26)]
  FROM character_log GROUP BY character_id ORDER BY count(*) DESC LIMIT 1
  """)

IO.puts("Longest chronicle: #{entries} entries\n")

{branch, 0} = System.cmd("git", ~w(rev-parse --abbrev-ref HEAD))
tag = System.get_env("BENCH_TAG") || String.trim(branch)
saved = "tmp/bench/board-#{tag}.benchee"

Benchee.run(
  %{
    "board, every lineage" => fn -> Board.current() end,
    "one run's entry" => fn -> Board.entry(longest) end,
    "chronicle, newest page" => fn -> CharacterLog.page(longest) end,
    "chronicle, oldest page" => fn -> CharacterLog.page(longest, oldest_page) end
  },
  time: 3,
  memory_time: 1,
  load: Enum.reject(Path.wildcard("tmp/bench/board-*.benchee"), &(&1 == saved)),
  save: [path: saved, tag: tag]
)
