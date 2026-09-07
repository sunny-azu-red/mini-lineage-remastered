# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

# The repo-root .env is shared with the TypeScript reference implementation, so both stacks read
# one set of database credentials. Only these keys are imported — .env also carries a PORT meant
# for the Node app, and adopting it would make Phoenix fight that server for the port.
env_file = Path.expand("../../.env", __DIR__)

if File.exists?(env_file) do
  for line <- File.stream!(env_file),
      [key, value] <- [String.split(String.trim(line), "=", parts: 2)],
      String.starts_with?(key, "DB_"),
      System.get_env(key) == nil do
    System.put_env(key, value)
  end
end

# How long a character survives without being played. It is a SLIDING window — the clock restarts
# every time you touch the character — and the session cookie is issued for exactly the same span,
# so the two can never disagree about whether your character is still there.
config :mini_lineage, character_ttl_hours: 24 * 30

config :mini_lineage,
  ecto_repos: [MiniLineage.Repo],
  generators: [timestamp_type: :utc_datetime]

# Configure the endpoint
config :mini_lineage, MiniLineageWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: MiniLineageWeb.ErrorHTML, json: MiniLineageWeb.ErrorJSON],
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
