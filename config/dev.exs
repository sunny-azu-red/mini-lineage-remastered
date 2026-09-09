import Config

config :mini_lineage, MiniLineageWeb.Endpoint,
  # Loopback only; {0, 0, 0, 0} to reach it from another machine.
  http: [ip: {127, 0, 0, 1}],
  check_origin: false,
  code_reloader: true,
  # Off deliberately: the game renders its own error screen, naming the reason here and withholding
  # it in a release, so what you see locally is what a player sees.
  debug_errors: false,
  secret_key_base: "lz2cr4M4G8Ux3ZZ8pdfpwEBX9Z+GHSgoycunMbd0+w7uMhPhYi5td3RPxnCss2Zp",
  watchers: [
    esbuild: {Esbuild, :install_and_run, [:mini_lineage, ~w(--sourcemap=inline --watch)]}
  ]

# Enable dev routes for dashboard and mailbox
config :mini_lineage, dev_routes: true

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
