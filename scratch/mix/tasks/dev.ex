defmodule Mix.Tasks.Dev do
  @shortdoc "Runs the game against your real dev data"

  @moduledoc """
      mix dev

  The development server, on PORT (4000), against the database in DB_DATABASE. This is what bare
  `mix` runs.

  It does not migrate — that is a deployment step, and `mix start` does it. Run `mix ecto.migrate`
  yourself after pulling a schema change.
  """
  use Mix.Task

  alias MiniLineage.Scratch.Shell

  @release "_build/prod/rel/mini_lineage/bin/mini_lineage"

  @impl Mix.Task
  def run(args) do
    # A release left running by `mix prod` holds this port, and Phoenix would report only
    # :eaddrinuse followed by thirty lines of every application shutting down in turn.
    if File.exists?(@release) do
      case Shell.running_pid(Path.expand(@release)) do
        nil ->
          :ok

        pid ->
          Mix.raise("""
          a release built by `mix prod` is still running as OS pid #{pid}, and it holds this port.

          Stop it with `mix stop`. Ctrl-C did not, because Erlang spawns it into its own process
          group, where this terminal's interrupt never reaches it.
          """)
      end
    end

    Mix.Task.run("phx.server", args)
  end
end
