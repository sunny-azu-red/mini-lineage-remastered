import Config

# Every setting an environment overrides, defaulted here and nowhere else: the code reads each one
# with compile_env!/fetch_env!, so a missing key fails loudly instead of falling back to a copy.

# How long an unplayed run keeps its session: a sliding window, and the session cookie's max_age.
config :mini_lineage, character_ttl_hours: 24 * 30

# How long a character process outlives its last viewer before it flushes and stops.
config :mini_lineage, character_idle_grace_ms: 10_000

# Rules §11's three seconds: a regen rate is what one tick restores. The browser suites wait on it.
config :mini_lineage, tick_interval_ms: 3_000

# Whether the error page may show a stack trace. Off in prod.exs, never derived from the version.
config :mini_lineage, debug_build: true

# A `secure` cookie is not sent over plain http, which a local server is. Set in prod.exs.
config :mini_lineage, secure_cookie: false

# Rules §15: every time the game keeps is UTC, and this zone only decides which hours are night.
config :mini_lineage, time_zone: "Europe/Bucharest"

config :elixir, :time_zone_database, Tz.TimeZoneDatabase

# The footer's name for an unreleased build.
config :mini_lineage, build_label: "development"

config :mini_lineage,
  ecto_repos: [MiniLineage.Repo],
  generators: [timestamp_type: :utc_datetime]

config :mini_lineage, MiniLineageWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: MiniLineageWeb.ErrorHTML],
    layout: false
  ],
  pubsub_server: MiniLineage.PubSub,
  live_view: [signing_salt: "+jRa52uF"]

config :esbuild,
  version: "0.28.2",
  mini_lineage: [
    args:
      ~w(js/app.js css/app.css --bundle --target=es2022 --outdir=../priv/static/assets --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__)]}
  ]

config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :phoenix, :json_library, Jason

# Last, so an environment's settings override everything above.
import_config "#{config_env()}.exs"
