import Config

config :mini_lineage, MiniLineageWeb.Endpoint,
  # Loopback only; {0, 0, 0, 0} to reach it from another machine.
  http: [ip: {127, 0, 0, 1}],
  check_origin: false,
  code_reloader: true,
  # Off: the game's own error screen shows the trace in a debug build, so dev sees a player's page.
  debug_errors: false,
  secret_key_base: "lz2cr4M4G8Ux3ZZ8pdfpwEBX9Z+GHSgoycunMbd0+w7uMhPhYi5td3RPxnCss2Zp",
  watchers: [
    esbuild: {Esbuild, :install_and_run, [:mini_lineage, ~w(--sourcemap=inline --watch)]}
  ]

# Cached per VM elsewhere; here a code reload must reach the race templates without a restart.
config :mini_lineage, cache_catalog: false

# Do not include metadata nor timestamps in development logs
config :logger, :default_formatter, format: "[$level] $message\n"

# Set a higher stacktrace during development. Avoid configuring such
# in production as building large stacktraces may be expensive.
config :phoenix, :stacktrace_depth, 20

# Initialize plugs at runtime for faster development compilation
config :phoenix, :plug_init_mode, :runtime

config :phoenix_live_view,
  # Include debug annotations and locations in rendered markup.
  # Changing this configuration will require mix clean and a full recompile.
  debug_heex_annotations: true,
  debug_attributes: true,
  # Enable helpful, but potentially expensive runtime checks
  enable_expensive_runtime_checks: true

# No script injected into the page, so the CSP stands as prod has it; the DevTools panel reads the
# config tag `Layouts.head` renders. No update checks: dev calls nothing outward either.
config :live_debugger, browser_features?: false, update_checks?: false
