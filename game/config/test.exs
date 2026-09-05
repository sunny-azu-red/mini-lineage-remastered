import Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
# A separate database from dev, so a test run can never touch real highscores or statistics.
config :mini_lineage, MiniLineage.Repo,
  username: System.get_env("DB_USERNAME", "root"),
  password: System.get_env("DB_PASSWORD", ""),
  hostname: System.get_env("DB_HOST", "127.0.0.1"),
  port: String.to_integer(System.get_env("DB_PORT", "3306")),
  database:
    "#{System.get_env("TEST_DATABASE", "lineage_remastered_test")}#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :mini_lineage, MiniLineageWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "55QIFRf6Cq76U5q1dMFfAHYYYJhBDJNByo7OxWqvnWqrhJTInC5yGdrN7RPpb5LF",
  server: false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Sort query params output of verified routes for robust url comparisons
config :phoenix,
  sort_verified_routes_query_params: true

# The idle grace only needs to be observably non-zero here.
config :mini_lineage, character_idle_grace_ms: 150

config :mini_lineage, start_statistics_collector: false
