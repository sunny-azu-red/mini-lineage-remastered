defmodule Mix.Tasks.E2e do
  @shortdoc "Runs the browser suites, server and all"

  @moduledoc """
      mix e2e                # both suites
      mix e2e walkthrough    # one character, played normally
      mix e2e races          # every lineage

  One command, one terminal. It starts the isolated server on the port `.env.test` names, empties
  that database's board, drives Chromium through the suites, and stops the server it started. A
  server already listening there is used as it is, and left running.

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

    port = e2e_port()
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

  # The server reads .env.test, so that file decides. The environment answers only when there is no
  # file, which is how CI supplies it.
  #
  # Deliberately not the other way around: this task runs in :dev, where .env would otherwise hand
  # it PORT=4000 and it would sit waiting on the development server's port. That it does not today
  # is luck — a Mix task does not start the application, so runtime.exs never runs and never puts
  # PORT into the environment. Adding `app.start` here would be enough to break it silently.
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
