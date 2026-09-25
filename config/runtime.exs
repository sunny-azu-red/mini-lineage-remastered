import Config

# runtime.exs is the ONLY configuration a release evaluates — config.exs and friends are baked in
# at build time — so everything that reads the environment belongs here, and `mix phx.server` and
# `bin/mini_lineage start` behave the same way.

# Credentials live in .env, the throwaway database's in .env.test — chosen here so every entry
# point agrees. ENV_FILE names the file elsewhere; a real environment variable beats it.
default_env_file = if config_env() in [:test, :e2e], do: ".env.test", else: ".env"
env_file = System.get_env("ENV_FILE") || Path.expand(default_env_file, File.cwd!())

# A quoted value is taken verbatim, so it may contain anything. An unquoted one ends at the first
# " #", which is how a trailing comment is written — a bare # with no space before it is part of
# the value, so a password containing one survives.
read_value = fn
  "\"" <> rest -> rest |> String.split("\"") |> hd()
  "'" <> rest -> rest |> String.split("'") |> hd()
  plain -> plain |> String.split(~r/\s+#/, parts: 2) |> hd() |> String.trim()
end

if File.exists?(env_file) do
  for line <- File.stream!(env_file),
      line = String.trim(line),
      line != "",
      not String.starts_with?(line, "#"),
      [key, value] <- [String.split(line, "=", parts: 2)],
      System.get_env(key) == nil do
    System.put_env(key, read_value.(String.trim(value)))
  end
end

credentials = [
  username: System.get_env("DB_USERNAME", "postgres"),
  password: System.get_env("DB_PASSWORD", ""),
  hostname: System.get_env("DB_HOST", "127.0.0.1"),
  port: String.to_integer(System.get_env("DB_PORT", "5432"))
]

if config_env() == :test do
  config :mini_lineage,
         MiniLineage.Repo,
         credentials ++
           [
             database:
               "#{System.get_env("DB_DATABASE", "lineage_remastered_test")}#{System.get_env("MIX_TEST_PARTITION")}",
             pool: Ecto.Adapters.SQL.Sandbox,
             pool_size: System.schedulers_online() * 2
           ]
end

if config_env() in [:dev, :e2e] do
  config :mini_lineage,
         MiniLineage.Repo,
         credentials ++
           [
             database: System.get_env("DB_DATABASE", "lineage_remastered_dev"),
             stacktrace: true,
             show_sensitive_data_on_connection_error: true,
             pool_size: 10
           ]
end

# dev and prod read the same .env and so play the same characters, but a cookie is only readable
# by the secret that signed it — so without this, switching between `mix dev` and `mix prod` looks
# to the browser like a brand-new visitor while its character sits in the database untouched.
if config_env() in [:dev, :e2e] do
  if secret = System.get_env("SECRET_KEY_BASE") do
    config :mini_lineage, MiniLineageWeb.Endpoint, secret_key_base: secret
  end
end

# Both are read at runtime by the code that uses them, so they are settable per deployment without
# a rebuild. Neither may be a compile_env, and neither has a compile-time default to disagree with.
if level = System.get_env("LOG_LEVEL") do
  levels = ~w(emergency alert critical error warning notice info debug)

  unless level in levels do
    raise "LOG_LEVEL is #{inspect(level)}; it must be one of #{Enum.join(levels, ", ")}"
  end

  config :logger, level: String.to_existing_atom(level)
end

if throttle = System.get_env("RATE_LIMIT") do
  config :mini_lineage, rate_limit: throttle in ~w(true 1)
end

# A release does not serve unless told to: PHX_SERVER=true bin/mini_lineage start.
if System.get_env("PHX_SERVER") do
  config :mini_lineage, MiniLineageWeb.Endpoint, server: true
end

# Not in :test, which pins its own port and never serves.
if config_env() != :test do
  config :mini_lineage, MiniLineageWeb.Endpoint,
    http: [port: String.to_integer(System.get_env("PORT", "4000"))]
end

if config_env() == :dev do
  # Reload browser tabs when matching files change.
  config :mini_lineage, MiniLineageWeb.Endpoint,
    live_reload: [
      web_console_logger: true,
      patterns: [
        # Static assets, except user uploads
        ~r"priv/static/(?!uploads/).*\.(js|css|png|jpeg|jpg|gif|svg)$"E,
        # Router, Controllers, LiveViews and LiveComponents
        ~r"lib/mini_lineage_web/router\.ex$"E,
        ~r"lib/mini_lineage_web/(controllers|live|components)/.*\.(ex|heex)$"E
      ]
    ]
end

if config_env() == :prod do
  # Compose forwards a key it was never given as an empty string, which `||` would take as set.
  env = fn name -> if (value = System.get_env(name)) not in [nil, ""], do: value end

  # DATABASE_URL still works for a host that offers only one, but it cannot carry a password with
  # URL-unsafe characters unless they are percent-encoded, so the discrete keys win when both are set.
  database_config =
    cond do
      database = env.("DB_DATABASE") ->
        credentials ++ [database: database]

      url = env.("DATABASE_URL") ->
        [url: url]

      true ->
        raise """
        no database configured.
        Set DB_DATABASE (with DB_USERNAME, DB_PASSWORD and optionally DB_HOST, DB_PORT) in the
        environment or in a .env beside the release, or a single DATABASE_URL.
        """
    end

  maybe_ipv6 = if System.get_env("ECTO_IPV6") in ~w(true 1), do: [:inet6], else: []

  config :mini_lineage,
         MiniLineage.Repo,
         database_config ++
           [
             pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
             socket_options: maybe_ipv6
           ]

  # Signs the session cookie. Must be at least 64 bytes, or every request fails.
  secret_key_base =
    env.("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  # Not defaulted. `check_origin` is unset, so Phoenix compares every websocket's Origin against
  # this host: wrong, and the page renders once and never connects, with nothing in the log to say
  # why. A deployment that cannot name its own host is not one that should boot.
  host =
    env.("PHX_HOST") ||
      raise """
      environment variable PHX_HOST is missing.

      It is the host this deployment answers on, and the LiveView socket refuses every origin that
      is not it, so an unset one serves a page that loads and then does nothing. Set it to the
      domain players reach, or to `localhost` for a local release.
      """

  config :mini_lineage, MiniLineageWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      # All interfaces, IPv6 included.
      ip: {0, 0, 0, 0, 0, 0, 0, 0}
    ],
    secret_key_base: secret_key_base
end
