defmodule Mix.Tasks.Prod do
  @shortdoc "Tests, builds a release, migrates, and serves it"

  @moduledoc """
      mix prod

  `mix build` then `mix start`, exactly as `npm run prod` was `npm run build && npm run start`.
  It stops at the first failing test and deploys nothing.

  Compiled only in :dev, so no release carries the task that builds it.
  """
  use Mix.Task

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("build", args)
    Mix.Task.run("start", args)
  end
end
