defmodule MiniLineage.MixProject do
  use Mix.Project

  def project do
    [
      app: :mini_lineage,
      version: "1.7.0",
      elixir: "~> 1.20",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      compilers: [:phoenix_live_view] ++ Mix.compilers(),
      # Reports, never gates: the browser suites are not instrumented, so the figure understates.
      test_coverage: [summary: [threshold: 0]],
      listeners: [Phoenix.CodeReloader],
      releases: [mini_lineage: [steps: [&require_stamp!/1, :assemble]]]
    ]
  end

  # A release always names its commit. Checked at assembly: a compile-time check fails every task
  # after the next commit.
  defp require_stamp!(release) do
    if Application.get_env(:mini_lineage, :app_version) in [nil, ""] do
      Mix.raise("""
      no APP_VERSION, and no git checkout to take one from.

      A production build names the commit it came from. Pass it:

          docker build --build-arg APP_VERSION=$(git rev-parse --short=7 HEAD) .
      """)
    end

    release
  end

  def application do
    [
      mod: {MiniLineage.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  def cli do
    [
      # Bare `mix` would otherwise `run`, boot an endpoint that does not serve, and exit silently.
      default_task: "dev",
      preferred_envs: [precommit: :test]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]

  # The balance simulations and dev Mix tasks; a release must not carry them.
  defp elixirc_paths(:dev), do: ["lib", "scratch"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:phoenix, "~> 1.8.13"},
      {:phoenix_ecto, "~> 4.5"},
      {:ecto_sql, "~> 3.13"},
      {:postgrex, ">= 0.0.0"},
      {:phoenix_html, "~> 4.1"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 1.2.0"},
      {:lazy_html, ">= 0.1.0", only: :test},
      {:esbuild, "~> 0.10", runtime: Mix.env() == :dev},
      {:jason, "~> 1.2"},
      {:bandit, "~> 1.5"},
      {:live_debugger, "~> 1.0", only: :dev},
      {:tidewave, "~> 0.9.1", only: :dev},
      {:benchee, "~> 1.5", only: :dev},
      {:stream_data, "~> 1.4", only: :test}
    ]
  end

  defp aliases do
    [
      setup: ["deps.get", "ecto.setup", "assets.setup", "assets.build", "e2e.setup"],
      "e2e.setup": ["cmd npm ci", "cmd npx playwright install chromium"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      "test.coverage": ["test --cover"],
      "assets.setup": ["esbuild.install --if-missing"],
      "assets.build": ["esbuild mini_lineage"],
      "assets.deploy": ["esbuild mini_lineage --minify", "phx.digest"],
      precommit: [
        "compile --warnings-as-errors",
        "deps.unlock --unused",
        "format",
        "test --warnings-as-errors"
      ]
    ]
  end
end
