defmodule MiniLineage.MixProject do
  use Mix.Project

  def project do
    [
      app: :mini_lineage,
      version: "1.5.0",
      elixir: "~> 1.17",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      compilers: [:phoenix_live_view] ++ Mix.compilers(),
      # Reports rather than gates. The browser walkthrough is where the web layer is exercised and
      # it is not instrumented, so this number understates what is actually covered — a threshold
      # here would fail honestly-tested code and teach everyone to ignore it.
      test_coverage: [summary: [threshold: 0]],
      listeners: [Phoenix.CodeReloader],
      releases: [mini_lineage: [steps: [&require_stamp!/1, :assemble]]]
    ]
  end

  # A release names the commit it came from — there is no such thing as one that cannot say which
  # it is. Checked as the release is assembled, which is the moment it becomes a thing that can be
  # deployed. Not at compile time: the sha changes with every commit, so a compile-time check makes
  # `mix prod` fail after each one until _build is thrown away.
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

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {MiniLineage.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  def cli do
    [
      # Bare `mix` otherwise runs Mix's own default, `run`, which boots the app, finds the endpoint
      # configured not to serve, and exits having printed nothing. It belongs here rather than in
      # `project/0`: once cli/0 exists, Mix reads the setting from it alone.
      default_task: "dev",
      preferred_envs: [precommit: :test]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]

  # The balance simulations and their `mix balance` task are a dev tool; a release must not carry them.
  defp elixirc_paths(:dev), do: ["lib", "scratch"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:phoenix, "~> 1.8.13"},
      {:phoenix_ecto, "~> 4.5"},
      {:ecto_sql, "~> 3.13"},
      {:myxql, ">= 0.0.0"},
      {:phoenix_html, "~> 4.1"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 1.2.0"},
      {:lazy_html, ">= 0.1.0", only: :test},
      {:esbuild, "~> 0.10", runtime: Mix.env() == :dev},
      {:jason, "~> 1.2"},
      {:bandit, "~> 1.5"}
    ]
  end

  defp aliases do
    [
      setup: ["deps.get", "ecto.setup", "assets.setup", "assets.build", "e2e.setup"],
      "e2e.setup": ["cmd npm ci", "cmd npx playwright install chromium"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      # `npm run test:coverage` had no counterpart; --cover is built in, this just names it.
      "test.coverage": ["test --cover"],
      "assets.setup": ["esbuild.install --if-missing"],
      "assets.build": ["compile", "esbuild mini_lineage"],
      # `compile` first, as assets.build does: the LiveView compiler generates the colocated hooks
      # app.js imports, into _build, and esbuild cannot resolve them before they exist. A warm
      # _build hides this; a clean one — CI, Docker, a fresh clone — does not.
      "assets.deploy": ["compile", "esbuild mini_lineage --minify", "phx.digest"],
      precommit: [
        "compile --warnings-as-errors",
        "deps.unlock --unused",
        "format",
        "test --warnings-as-errors"
      ]
    ]
  end
end
