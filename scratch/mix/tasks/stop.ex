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
        Shell.step("Stopping OS pid #{pid}", release, ["stop"])
        Mix.shell().info([:green, "\nStopped.", :reset])
    end
  end
end
