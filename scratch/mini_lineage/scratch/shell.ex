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
