#!/usr/bin/env bash
# Serves the app against an isolated database, so a browser walkthrough — which creates
# characters, spends adena and submits highscores — never touches the real dev data.
set -euo pipefail
cd "$(dirname "$0")/.."
# Only where the toolchain is not already on PATH: this machine keeps it under ~/.local, CI does not.
if [ -f ./env.sh ]; then
  # shellcheck disable=SC1091
  source ./env.sh
fi
# Its own MIX_ENV, so the build lands in the already-ignored _build/e2e rather than under the dev
# server someone may be playing on, and so config/runtime.exs reads .env.test — which is where the
# throwaway database and this server's own port come from.
export MIX_ENV=e2e

mix ecto.migrate >/dev/null

# The walkthrough is only worth running against the bundle in the working tree. Code reloading is
# off here, which turns Plug.Static's gzip on, so a `.gz` left behind by an earlier
# `mix assets.deploy` is served in preference to a freshly built app.js — the browser then runs
# whatever JS was current when that release was cut. Clear the digests, then build.
mix phx.digest.clean --all >/dev/null
mix assets.build >/dev/null

exec mix phx.server
