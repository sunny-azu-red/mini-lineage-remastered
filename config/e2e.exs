import Config

# The dev configuration under its own MIX_ENV, so its build in _build/e2e never disturbs a dev
# server. Database and port come from .env.test.
import_config "dev.exs"

# Nothing recompiles underneath a run, and phoenix_live_reload is :dev-only anyway.
config :mini_lineage, MiniLineageWeb.Endpoint,
  code_reloader: false,
  live_reload: [patterns: []]

# The suites drive what ships, and what ships caches.
config :mini_lineage, cache_catalog: true

# Tells this unreleased build apart from the dev server in the footer.
config :mini_lineage, build_label: "testing"

# A page the suites can outgrow with a dozen dice-free purchases; the paging is the same at 50.
config :mini_lineage, chronicle_page: 10
