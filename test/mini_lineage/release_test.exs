defmodule MiniLineage.ReleaseTest do
  @moduledoc """
  How a deployed release migrates, having no Mix to do it with.

  Only the configuration is checked here, and deliberately so: `migrate/0` and `rollback/2` run
  migrations, whose DDL commits implicitly. That ends the sandbox transaction the suite runs in,
  and loading a migration file a second time warns about redefining its module — which the suite
  now treats as an error. Both were tried. The migrations themselves are exercised every time the
  browser suites start their server, and a rollback is rehearsed by hand against a scratch copy of
  the schema before it is ever pointed at real data.

  What is worth pinning is the one way these can fail silently: with `:ecto_repos` unset,
  `migrate/0` iterates an empty list, reports nothing wrong, and a deploy serves an unmigrated
  database.
  """
  use ExUnit.Case, async: true

  test "the repos it migrates are configured, or it would quietly migrate nothing" do
    assert Application.fetch_env!(:mini_lineage, :ecto_repos) == [MiniLineage.Repo]
  end

  test "and the entry points a release calls by name are there to call" do
    # `bin/mini_lineage eval 'MiniLineage.Release.migrate()'` is in the Dockerfile's CMD, and
    # rollback/2 is in the README. A rename would break a deploy rather than a test.
    Code.ensure_loaded!(MiniLineage.Release)

    assert function_exported?(MiniLineage.Release, :migrate, 0)
    assert function_exported?(MiniLineage.Release, :rollback, 2)
  end
end
