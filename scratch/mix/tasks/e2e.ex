defmodule Mix.Tasks.E2e do
  @shortdoc "Runs the browser suites, server and all"

  @moduledoc """
      mix e2e                # both suites
      mix e2e walkthrough    # one character, played normally
      mix e2e races          # every lineage

  One command, one terminal. It starts the isolated server on PORT_E2E against DB_DATABASE_TEST,
  empties the board, drives Chromium through the suites, and stops the server it started. A server
  already listening there is used as it is, and left running.

  Compiled only in :dev, so no release carries the task that tests it.
  """
  use Mix.Task

  alias MiniLineage.Scratch.Shell

  @suites %{"walkthrough" => "e2e/walkthrough.mjs", "races" => "e2e/races.mjs"}
  @boot_timeout_ms 90_000

  @impl Mix.Task
  def run(args) do
    suites =
      case args do
        [] -> ["walkthrough", "races"]
        given -> Enum.map(given, &validate!/1)
      end

    port = System.get_env("PORT_E2E", "4002")
    Shell.require_browser!()
    lock = Shell.lock!("_build/e2e.lock")

    try do
      {owned, url} = Shell.ensure_server(port, @boot_timeout_ms)

      try do
        Enum.each(suites, fn suite ->
          # Emptied per suite: each one assumes a board only it put entries on.
          Shell.step("resetting the board", Path.expand("e2e/reset.sh"), [])
          Shell.step("#{suite} (#{url})", "node", [@suites[suite]], nil, [{"E2E_BASE_URL", url}])
        end)
      after
        if owned, do: Shell.stop_server(owned)
      end
    after
      Shell.unlock(lock)
    end

    Mix.shell().info([:green, "\n✔ #{Enum.join(suites, " and ")} passed", :reset])
  end

  defp validate!(name) when is_map_key(@suites, name), do: name

  defp validate!(name),
    do:
      Mix.raise("no suite called #{inspect(name)} — try #{Enum.join(Map.keys(@suites), " or ")}")
end
