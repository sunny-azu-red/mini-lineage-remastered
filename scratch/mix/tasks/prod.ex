defmodule Mix.Tasks.Prod do
  @shortdoc "Tests, builds a release, migrates, and serves it"

  @moduledoc """
  The whole path to a running production build, in one command:

      mix prod

  Tests first, and it stops there if any fail — a build that does not pass is not one worth
  deploying. Then dependencies, minified and digested assets, the release itself, pending
  migrations, and finally the server in the foreground.

  Each step runs as its own `mix` process, because MIX_ENV is fixed for the life of one: the tests
  need :test and everything after them needs :prod, and no alias can switch between them.

  Compiled only in :dev, so no release carries this task.
  """
  use Mix.Task

  @release "_build/prod/rel/mini_lineage/bin/mini_lineage"

  @impl Mix.Task
  def run(_args) do
    step("Tests", "mix", ["test"], "test")
    step("Dependencies", "mix", ["deps.get", "--only", "prod"], "prod")
    step("Assets", "mix", ["assets.deploy"], "prod")
    step("Release", "mix", ["release", "--overwrite"], "prod")

    unless File.exists?(@release), do: Mix.raise("the release is missing at #{@release}")

    # Absolute: System.cmd/3 does not resolve a relative executable the way a shell would.
    release = Path.expand(@release)

    step("Migrations", release, ["eval", "MiniLineage.Release.migrate()"], nil)

    Mix.shell().info([:green, "\n▶ Serving. Ctrl-C twice to stop.\n", :reset])
    step("Server", release, ["start"], nil, [{"PHX_SERVER", "true"}])
  end

  defp step(label, command, args, mix_env, extra_env \\ []) do
    Mix.shell().info([:cyan, "\n▶ #{label}", :reset])

    env = if mix_env, do: [{"MIX_ENV", mix_env} | extra_env], else: extra_env

    case System.cmd(command, args,
           env: env,
           into: IO.stream(:stdio, :line),
           stderr_to_stdout: true
         ) do
      {_output, 0} -> :ok
      {_output, code} -> Mix.raise("#{label} failed with exit status #{code} — nothing deployed.")
    end
  end
end
