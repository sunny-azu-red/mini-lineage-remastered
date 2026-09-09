import Config

# Stamped at BUILD time: a release has no git checkout to ask at boot. Only the footer's commit
# link depends on it.
app_version =
  case System.get_env("APP_VERSION") do
    given when is_binary(given) and given != "" ->
      given

    _ ->
      try do
        case System.cmd("git", ["rev-parse", "--short=7", "HEAD"], stderr_to_stdout: true) do
          {sha, 0} -> String.trim(sha)
          _ -> nil
        end
      rescue
        _ -> nil
      end
  end

config :mini_lineage, :app_version, app_version

# Whatever the version turned out to be, a production build tells a player nothing.
config :mini_lineage, debug_build: false

# The digested filenames, written by `mix assets.deploy`.
config :mini_lineage, MiniLineageWeb.Endpoint,
  cache_static_manifest: "priv/static/cache_manifest.json"

# Force using SSL in production. This also sets the "strict-security-transport" header,
# known as HSTS. If you have a health check endpoint, you may want to exclude it below.
# Note `:force_ssl` is required to be set at compile-time.
config :mini_lineage, MiniLineageWeb.Endpoint,
  force_ssl: [
    rewrite_on: [:x_forwarded_proto],
    exclude: [
      # paths: ["/health"],
      hosts: ["localhost", "127.0.0.1"]
    ]
  ]

# Do not print debug messages in production
config :logger, level: :info

# Runtime production configuration, including reading
# of environment variables, is done on config/runtime.exs.

# Throttling is on only for a real deployment; local development is never throttled.
config :mini_lineage, rate_limit: true
