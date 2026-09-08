defmodule Mix.Tasks.Start do
  @shortdoc "Migrates, then serves the release already built"

  @moduledoc """
      mix start

  Applies pending migrations and serves the built release in the foreground — the same pair the
  container runs, so a fresh database is never served against. Build it first with `mix build`,
  or use `mix prod` for both.
  """
  use Mix.Task

  alias MiniLineage.Scratch.Shell

  @impl Mix.Task
  def run(_args) do
    release = Shell.release!()

    Shell.step("Migrations", release, ["eval", "MiniLineage.Release.migrate()"])

    Mix.shell().info([:green, "\n▶ Serving. Ctrl-C twice to stop.\n", :reset])
    Shell.step("Server", release, ["start"], nil, [{"PHX_SERVER", "true"}])
  end
end
