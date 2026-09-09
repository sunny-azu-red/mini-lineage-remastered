import Config

# How long a character survives unplayed — a SLIDING window, and the same span the session cookie
# is issued for, so the two cannot disagree about whether a character is still there.
config :mini_lineage, character_ttl_hours: 24 * 30

# May this build show its internals? Overridden in prod.exs. Not derived from the version: a
# deployment that stamps no sha should lose the footer's commit link, never gain a stack trace.
config :mini_lineage, debug_build: true

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

# Configure LiveView
config :phoenix_live_view,
  # the attribute set on all root tags. Used for Phoenix.LiveView.ColocatedCSS.
  root_tag_attribute: "phx-r"

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.25.4",
  mini_lineage: [
    args:
      ~w(js/app.js css/app.css --bundle --target=es2022 --outdir=../priv/static/assets --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
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
