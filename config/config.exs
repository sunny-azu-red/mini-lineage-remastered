import Config

# Every setting an environment overrides, defaulted here and nowhere else: the code reads each one
# with compile_env!/fetch_env!, so a missing key fails loudly instead of falling back to a copy.

# How long an unplayed run keeps its session: a sliding window, and the session cookie's max_age.
config :mini_lineage, character_ttl_hours: 24 * 30

# How long a character process outlives its last viewer before it flushes and stops.
config :mini_lineage, character_idle_grace_ms: 10_000

# Chronicle entries per page; the next page loads as the reader nears the end.
config :mini_lineage, chronicle_page: 25

# How long a `<.stamp>` says an age ("4m ago") before it names the date instead.
config :mini_lineage, stamp_relative_days: 7

# Throttling. On in prod.exs; RATE_LIMIT overrides it at boot.
config :mini_lineage, rate_limit: false

# Whether the error page may show a stack trace. Off in prod.exs, never derived from the version.
config :mini_lineage, debug_build: true

# A `secure` cookie is not sent over plain http, which a local server is. Set in prod.exs.
config :mini_lineage, secure_cookie: false

# Caches the catalog per VM. dev turns it off, so a code reload reaches the race templates.
config :mini_lineage, cache_catalog: true

# The footer's name for an unreleased build.
config :mini_lineage, build_label: "development"

# Timer-driven processes, which test.exs turns off because they would fight the SQL sandbox.
config :mini_lineage, start_statistics_collector: true, start_board: true

config :mini_lineage,
  ecto_repos: [MiniLineage.Repo],
  generators: [timestamp_type: :utc_datetime]

# Configure the endpoint
config :mini_lineage, MiniLineageWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: MiniLineageWeb.ErrorHTML],
    layout: false
  ],
  pubsub_server: MiniLineage.PubSub,
  live_view: [signing_salt: "+jRa52uF"]

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.25.4",
  mini_lineage: [
    args:
      ~w(js/app.js css/app.css --bundle --target=es2022 --outdir=../priv/static/assets --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__)]}
  ]

# Configure Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
