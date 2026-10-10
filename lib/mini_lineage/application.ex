defmodule MiniLineage.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children =
      [
        MiniLineage.Repo,
        {Registry, keys: :unique, name: MiniLineage.Characters.Registry},
        {DynamicSupervisor, strategy: :one_for_one, name: MiniLineage.Characters.Supervisor},
        MiniLineage.Characters.Sweeper,
        {Phoenix.PubSub, name: MiniLineage.PubSub}
      ] ++
        if(Application.fetch_env!(:mini_lineage, :start_board), do: [MiniLineage.Board], else: [])

    # Last, so nothing serves a request before the pieces behind it are up.
    Supervisor.start_link(children ++ [MiniLineageWeb.Endpoint],
      strategy: :one_for_one,
      name: MiniLineage.Supervisor
    )
  end

  @impl true
  def config_change(changed, _new, removed) do
    MiniLineageWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
