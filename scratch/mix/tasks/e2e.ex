defmodule Mix.Tasks.E2e do
  @shortdoc "Runs the browser suites, server and all"

  @moduledoc """
      mix e2e                # every suite
      mix e2e walkthrough    # one character, played normally
      mix e2e races          # every starting set

  One command, one terminal. It migrates and empties the isolated database, starts its server on the
  port `.env.test` names, drives Chromium through the suites, and stops the server it started. A
  server already listening there is used as it is, and left running.

  Compiled only in :dev, so no release carries the task that tests it.
  """
  use Mix.Task

  alias MiniLineage.Scratch.Shell

  @suites %{
    "walkthrough" => "e2e/walkthrough.mjs",
    "races" => "e2e/races.mjs"
  }
  @boot_timeout_ms 90_000

  @impl Mix.Task
  def run(args) do
    suites =
      case args do
        [] -> ["walkthrough", "races"]
        given -> Enum.map(given, &validate!/1)
      end

    port = e2e_port()
    Shell.require_browser!()
    lock = Shell.lock!("_build/e2e.lock")

    try do
      # Migrated first, as CI's database is new.
      Shell.step("migrating", "mix", ["ecto.migrate", "--quiet"], "e2e")
      {owned, url} = Shell.ensure_server(port, @boot_timeout_ms)

      try do
        Enum.each(suites, fn suite ->
          Shell.step("resetting the database", Path.expand("e2e/reset.sh"), [])
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

  # .env.test decides, and the environment only without the file, as in CI: in :dev, .env would
  # hand this PORT=4000 and it would wait on the development server.
  defp e2e_port do
    with {:ok, contents} <- File.read(".env.test"),
         [_, port] <- Regex.run(~r/^\s*PORT\s*=\s*(\d+)/m, contents) do
      port
    else
      _ -> System.get_env("PORT", "4002")
    end
  end

  defp validate!(name) when is_map_key(@suites, name), do: name

  defp validate!(name),
    do:
      Mix.raise("no suite called #{inspect(name)} — try #{Enum.join(Map.keys(@suites), " or ")}")
end
