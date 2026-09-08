defmodule Mix.Tasks.Stop do
  @shortdoc "Stops a release left running by mix start or mix prod"

  @moduledoc """
      mix stop

  Ctrl-C does not stop the server `mix start` launches: Erlang spawns port children in their own
  process group, so the interrupt reaches the task and not the release. The release keeps the port
  and the node name, which is what makes the next `mix dev` fail with `:eaddrinuse` and the next
  `mix prod` complain that the node name is in use.
  """
  use Mix.Task

  alias MiniLineage.Scratch.Shell

  @impl Mix.Task
  def run(_args) do
    release = Shell.release!()

    case Shell.running_pid(release) do
      nil ->
        Mix.shell().info("Nothing running.")

      pid ->
        Mix.shell().info([:cyan, "\n▶ Stopping OS pid #{pid}", :reset])
        System.cmd(release, ["stop"], stderr_to_stdout: true)

        if Shell.await_exit(pid) do
          Mix.shell().info([:green, "Stopped.", :reset])
        else
          Mix.raise("""
          pid #{pid} is still running well after being asked to stop — something is holding
          shutdown open. `kill #{pid}` if you need the port back now.
          """)
        end
    end
  end
end
