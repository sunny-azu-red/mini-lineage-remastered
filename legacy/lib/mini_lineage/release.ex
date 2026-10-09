defmodule MiniLineage.Release do
  @moduledoc """
  Migration entry points for a built release, which has no Mix and so no `mix ecto.migrate`.

      bin/mini_lineage eval "MiniLineage.Release.migrate()"
  """
  @app :mini_lineage

  def migrate do
    load_app()

    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  def rollback(repo, version) do
    load_app()
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  defp repos, do: Application.fetch_env!(@app, :ecto_repos)

  # The repo is started by the migrator, not the supervision tree, so only load — never start.
  defp load_app do
    Application.load(@app)
  end
end
