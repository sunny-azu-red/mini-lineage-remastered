import Config

# The browser walkthrough runs the dev configuration, but under its own MIX_ENV so its build lands
# in _build/e2e and cannot disturb a dev server someone is playing on. Database and port come from
# the environment — see e2e/serve.sh.
import_config "dev.exs"

# No code reloading and no live-reload socket. A server being driven by a browser test should not
# recompile underneath the run, and phoenix_live_reload is a :dev-only dependency in any case.
config :mini_lineage, MiniLineageWeb.Endpoint,
  code_reloader: false,
  live_reload: [patterns: []]

# Its own name in the footer: this server and the dev one are both unreleased builds, and telling
# them apart at a glance is the whole point of the label.
config :mini_lineage, build_label: "🔥 testing"
