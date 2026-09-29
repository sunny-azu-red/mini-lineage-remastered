#!/usr/bin/env bash
# Serves the app against an isolated database, so a browser walkthrough — which creates
# characters, spends adena and fills the board — never touches the real dev data.
set -euo pipefail
cd "$(dirname "$0")/.."
# Only where the toolchain is not already on PATH: this machine keeps it under ~/.local, CI does not.
if [ -f ./env.sh ]; then
  # shellcheck disable=SC1091
  source ./env.sh
fi
# Its own MIX_ENV, so the build lands in _build/e2e rather than under the dev server, and
# config/runtime.exs reads .env.test, which names the throwaway database and this server's port.
export MIX_ENV=e2e

mix ecto.migrate >/dev/null

# Code reloading is off here, which turns Plug.Static's gzip on, so a `.gz` left by an earlier
# `mix assets.deploy` would win over a freshly built app.js. Clear the digests, then build.
mix phx.digest.clean --all >/dev/null
mix assets.build >/dev/null

exec mix phx.server
