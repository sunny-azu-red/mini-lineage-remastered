import Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :mini_lineage, MiniLineageWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "55QIFRf6Cq76U5q1dMFfAHYYYJhBDJNByo7OxWqvnWqrhJTInC5yGdrN7RPpb5LF",
  server: false

# Print only warnings and errors during test
config :logger, level: :warning

# Ecto's own query logging drowns any test that raises the level to inspect a debug line of ours.
config :mini_lineage, MiniLineage.Repo, log: false

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
