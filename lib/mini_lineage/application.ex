defmodule MiniLineage.Application do
  @moduledoc false

  use Application

  # Both work on a timer, which would fight the SQL sandbox; their own tests start them, and
  # `Board.current/0` computes in the caller when the process is absent.
  @optional [
    {:start_statistics_collector, MiniLineage.Game.Statistics.Collector},
    {:start_board, MiniLineage.Board}
  ]

  @impl true
  def start(_type, _args) do
    children =
      [
        MiniLineage.Repo,
        {Registry, keys: :unique, name: MiniLineage.Characters.Registry},
        {DynamicSupervisor, strategy: :one_for_one, name: MiniLineage.Characters.Supervisor},
        MiniLineage.Game.RateLimit,
        MiniLineage.Characters.Sweeper,
        {Phoenix.PubSub, name: MiniLineage.PubSub}
      ] ++
        for {setting, child} <- @optional,
            Application.get_env(:mini_lineage, setting, true),
            do: child

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
