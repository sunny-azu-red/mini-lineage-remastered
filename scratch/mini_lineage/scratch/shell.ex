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
