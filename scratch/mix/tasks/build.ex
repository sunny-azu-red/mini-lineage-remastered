defmodule Mix.Tasks.Build do
  @shortdoc "Tests, then builds a production release"

  @moduledoc """
      mix build

  Tests first, and it stops there if any fail — the same gate `prebuild` gave `npm run build`.
  Then production dependencies, minified and digested assets, and the release itself, stamped with
  the current commit so it identifies as a release rather than a debug build.

  Builds without serving. `mix prod` is this followed by `mix start`.
  """
  use Mix.Task

  alias MiniLineage.Scratch.Shell

  @impl Mix.Task
  def run(_args) do
    Shell.step("Tests", "mix", ["test"], "test")
    Shell.step("Dependencies", "mix", ["deps.get", "--only", "prod"], "prod")
    Shell.step("Assets", "mix", ["assets.deploy"], "prod")
    Shell.step("Release", "mix", ["release", "--overwrite"], "prod")
  end
end
