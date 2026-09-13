defmodule MiniLineage.ReleaseTest do
  @moduledoc """
  How a deployed release migrates, having no Mix to do it with.

  Configuration only: running a migration commits its DDL implicitly, which ends the sandbox
  transaction, and reloading the file warns about redefining the module. The migrations themselves
  are exercised every time the browser suites start their server.

  What is pinned here is the one silent failure: with `:ecto_repos` unset, `migrate/0` iterates an
  empty list, reports nothing wrong, and a deploy serves an unmigrated database.
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
