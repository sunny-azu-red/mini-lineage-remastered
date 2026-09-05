defmodule MiniLineage.Application do
  # See https://elixir.hexdocs.pm/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      MiniLineageWeb.Telemetry,
      MiniLineage.Repo,
      {DNSCluster, query: Application.get_env(:mini_lineage, :dns_cluster_query) || :ignore},
      {Registry, keys: :unique, name: MiniLineage.Characters.Registry},
      {DynamicSupervisor, strategy: :one_for_one, name: MiniLineage.Characters.Supervisor},
      {Phoenix.PubSub, name: MiniLineage.PubSub},
      # Start a worker by calling: MiniLineage.Worker.start_link(arg)
      # {MiniLineage.Worker, arg},
      # Start to serve requests, typically the last entry
      MiniLineageWeb.Endpoint
    ]

    # See https://elixir.hexdocs.pm/Supervisor.html
    # for other strategies and supported options
    # The collector writes on a timer, which would fight the SQL sandbox; its own test starts it.
    children =
      if Application.get_env(:mini_lineage, :start_statistics_collector, true),
        do: children ++ [MiniLineage.Game.Statistics.Collector],
        else: children

    opts = [strategy: :one_for_one, name: MiniLineage.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    MiniLineageWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
