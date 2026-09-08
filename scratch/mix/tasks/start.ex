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

    # Erlang spawns port children in their own process group, so Ctrl-C here never reaches the
    # server — it outlives the task that started it, holding the port and the node name. Better to
    # say so than to let the next run fail on :eaddrinuse and a node-name clash.
    if pid = Shell.running_pid(release) do
      Mix.raise("""
      a release is already running as OS pid #{pid}, holding the port and the node name.

      That is why `mix dev` reports :eaddrinuse and `mix prod` reports the node name in use.
      Stop it with `mix stop` — Ctrl-C does not, because the server is not in this terminal's
      process group.
      """)
    end

    Shell.step("Migrations", release, ["eval", "MiniLineage.Release.migrate()"])

    Mix.shell().info([:green, "\n▶ Serving. Ctrl-C twice to stop.\n", :reset])
    Shell.step("Server", release, ["start"], nil, [{"PHX_SERVER", "true"}])
  end
end
