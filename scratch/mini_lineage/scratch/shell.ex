defmodule MiniLineage.Scratch.Shell do
  @moduledoc """
  Runs one step of a build as its own OS process, and stops the build if it fails.

  Separate processes because MIX_ENV is fixed for the life of one: the tests need `:test` and
  everything after them needs `:prod`, so no single `mix` invocation — and no alias — can do both.
  Setting it per process also means an exported MIX_ENV cannot decide it for us.
  """
  @release "_build/prod/rel/mini_lineage/bin/mini_lineage"

  @doc "The built release binary, absolute — System.cmd/3 will not resolve a relative one."
  def release! do
    unless File.exists?(@release) do
      Mix.raise("no release at #{@release} — run `mix build` first.")
    end

    Path.expand(@release)
  end

  @doc """
  The OS pid of a release already running, or nil.

  `bin/... pid` exits 0 either way — it prints an RPC failure when nothing is there — so the output
  is what decides.
  """
  def running_pid(release) do
    case System.cmd(release, ["pid"], stderr_to_stdout: true) do
      {output, 0} ->
        pid = String.trim(output)
        if pid =~ ~r/^\d+$/, do: pid

      _ ->
        nil
    end
  end

  @doc """
  Blocks until an OS process is gone, or the timeout elapses. True if it went.

  `bin/... stop` returns as soon as its RPC is sent, and the VM takes another moment to actually
  go — longer with a browser still attached. Until it does, the port and the node name are still
  taken, so anything that reports success on the strength of that command alone is guessing.
  """
  def await_exit(pid, timeout_ms \\ 20_000) do
    deadline = System.monotonic_time(:millisecond) + timeout_ms

    Stream.repeatedly(fn ->
      if alive?(pid) and System.monotonic_time(:millisecond) < deadline do
        Process.sleep(100)
        :waiting
      else
        if alive?(pid), do: :timeout, else: :gone
      end
    end)
    |> Enum.find(&(&1 != :waiting))
    |> Kernel.==(:gone)
  end

  defp alive?(pid), do: match?({_, 0}, System.cmd("kill", ["-0", pid], stderr_to_stdout: true))

  @doc """
  Claims the right to run the browser suites on this machine, or says who already has it.

  Waiting would be worse than refusing: a run that queues behind another gets its server stopped
  the moment the first one finishes, and then drives a dead port. Both suites also empty the
  board and assume only their own entries are on it, so two at once corrupt each other's results
  rather than merely racing — which is what a stray suite run alongside a soak actually did.

  `mkdir` is the lock: it either creates the directory or it does not, with no window between.
  """
  def lock!(path) do
    File.mkdir_p!(Path.dirname(path))

    case File.mkdir(path) do
      :ok ->
        File.write!(Path.join(path, "pid"), to_string(System.pid()))
        path

      {:error, :eexist} ->
        holder =
          path
          |> Path.join("pid")
          |> File.read()
          |> case do
            {:ok, pid} -> String.trim(pid)
            _ -> nil
          end

        if holder && alive?(holder) do
          Mix.raise("""
          another browser run is in progress (pid #{holder}).

          They share one database, and each empties the board before it starts, so running two at
          once makes both report nonsense. Wait for that one, or stop it.
          """)
        else
          # Its owner is gone — a killed run, or a reboot. Take it over rather than blocking on a
          # directory nothing is holding.
          File.rm_rf!(path)
          lock!(path)
        end
    end
  end

  @doc "Releases the run lock."
  def unlock(path), do: File.rm_rf(path)

  @doc """
  Fails early, and by name, when the browser cannot start.

  Playwright's Chromium needs shared libraries this machine could not install system-wide, and
  without them it dies with a linker error buried in eighty lines of Chrome flags. `env.sh` puts
  them on LD_LIBRARY_PATH; this says so plainly rather than letting the run discover it.
  """
  def require_browser! do
    unless System.find_executable("node") do
      Mix.raise("""
      `node` is not on the PATH.

      It comes from nvm, which only loads itself for an interactive shell. `source env.sh` picks
      it up, and adding that to ~/.bashrc keeps it picked up.
      """)
    end

    unless File.dir?("node_modules/playwright") do
      Mix.raise("Playwright is not installed — run `mix setup`, or `npm ci` on its own.")
    end

    case System.cmd("node", ["-e", browser_probe()], stderr_to_stdout: true) do
      {_, 0} ->
        :ok

      {output, _} ->
        Mix.raise("""
        Chromium will not start.

        #{output |> String.split("\n") |> Enum.take(3) |> Enum.join("\n")}

        Its shared libraries live under ~/.local because this machine has no root, so they have to
        be on LD_LIBRARY_PATH. Source the project's environment and they will be:

            source env.sh

        Add it to ~/.bashrc to stop thinking about it:

            [ -f ~/mini-lineage-remastered/env.sh ] && source ~/mini-lineage-remastered/env.sh

        If the browser itself is missing, `npx playwright install chromium` fetches it.
        """)
    end
  end

  defp browser_probe do
    "import('playwright').then(p => p.chromium.launch()).then(b => b.close())" <>
      ".catch(e => { console.error(e.message); process.exit(1); })"
  end

  @doc """
  The e2e server, started if it is not already up. Returns `{owned_pid_or_nil, base_url}`.

  A server someone is already running is used as it is and left alone; only one this started is
  stopped afterwards.
  """
  def ensure_server(port, timeout_ms) do
    url = "http://localhost:#{port}"

    if responding?(url) do
      Mix.shell().info([:cyan, "\n▶ using the server already on #{url}", :reset])
      {nil, url}
    else
      Mix.shell().info([:cyan, "\n▶ starting the e2e server on #{url}", :reset])

      # PORT is handed down rather than left for the child to work out: an exported PORT in the
      # caller's shell would otherwise bind the server somewhere this is not watching.
      port_ref =
        Port.open({:spawn_executable, Path.expand("e2e/serve.sh")}, [
          :binary,
          :hide,
          args: [],
          env: [{~c"PORT", String.to_charlist(port)}]
        ])

      os_pid = Port.info(port_ref)[:os_pid]

      unless await(url, timeout_ms) do
        stop_server(os_pid)
        Mix.raise("the e2e server never came up on #{url} within #{div(timeout_ms, 1000)}s.")
      end

      {os_pid, url}
    end
  end

  @doc "Stops a server this task started, and everything it spawned."
  def stop_server(os_pid) do
    Mix.shell().info([:cyan, "\n▶ stopping the e2e server", :reset])
    # The whole group: serve.sh execs the BEAM, which is the process actually holding the port.
    System.cmd("pkill", ["-TERM", "-g", to_string(os_pid)], stderr_to_stdout: true)
    await_exit(to_string(os_pid), 20_000)
  end

  defp await(url, timeout_ms) do
    deadline = System.monotonic_time(:millisecond) + timeout_ms

    Stream.repeatedly(fn ->
      cond do
        responding?(url) -> :up
        System.monotonic_time(:millisecond) >= deadline -> :timeout
        true -> Process.sleep(250) && :waiting
      end
    end)
    |> Enum.find(&(&1 != :waiting))
    |> Kernel.==(:up)
  end

  defp responding?(url) do
    match?({_, 0}, System.cmd("curl", ["-sf", "-o", "/dev/null", url], stderr_to_stdout: true))
  end

  def step(label, command, args, mix_env \\ nil, extra_env \\ []) do
    Mix.shell().info([:cyan, "\n▶ #{label}", :reset])

    env = if mix_env, do: [{"MIX_ENV", mix_env} | extra_env], else: extra_env

    case System.cmd(command, args,
           env: env,
           into: IO.stream(:stdio, :line),
           stderr_to_stdout: true
         ) do
      {_output, 0} -> :ok
      {_output, code} -> Mix.raise("#{label} failed with exit status #{code} — stopping here.")
    end
  end
end
