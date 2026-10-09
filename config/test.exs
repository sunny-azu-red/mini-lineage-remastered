import Config

# Nothing serves here: the browser suites run under :e2e, on their own port.
config :mini_lineage, MiniLineageWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "55QIFRf6Cq76U5q1dMFfAHYYYJhBDJNByo7OxWqvnWqrhJTInC5yGdrN7RPpb5LF",
  server: false

config :logger, level: :warning

# Ecto's own query logging drowns any test that raises the level to inspect a debug line of ours.
config :mini_lineage, MiniLineage.Repo, log: false

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Sort query params output of verified routes for robust url comparisons
config :phoenix,
  sort_verified_routes_query_params: true

# The idle grace only needs to be observably non-zero here.
config :mini_lineage, character_idle_grace_ms: 150

# Only the ticks a test sends: one landing on its own under CI load moves an exact health figure.
config :mini_lineage, tick_interval_ms: :timer.hours(1)
