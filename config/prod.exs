import Config

# Stamped at build time, since a release has no checkout to ask. Only the footer's link reads it.
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

# That a release names its commit is enforced by a release step in mix.exs, not here.

# Whatever the version turned out to be, a production build tells a player nothing.
config :mini_lineage, debug_build: false

# force_ssl means every request arrives over https, so the session may insist on it.
config :mini_lineage, secure_cookie: true

# The digested filenames, written by `mix assets.deploy`.
config :mini_lineage, MiniLineageWeb.Endpoint,
  cache_static_manifest: "priv/static/cache_manifest.json"

# Every request over https, and the HSTS header that says so. Compile-time only, hence here rather
# than runtime.exs. localhost is excluded so compose's healthcheck reaches the game, not a redirect.
config :mini_lineage, MiniLineageWeb.Endpoint,
  force_ssl: [rewrite_on: [:x_forwarded_proto], exclude: [hosts: ["localhost", "127.0.0.1"]]]

# Do not print debug messages in production
config :logger, level: :info

# Throttling is on only for a real deployment; local development is never throttled.
config :mini_lineage, rate_limit: true
