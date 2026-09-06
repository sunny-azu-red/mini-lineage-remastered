#!/usr/bin/env bash
# Serves the app against an isolated database, so a browser walkthrough — which creates
# characters, spends adena and submits highscores — never touches the real dev data.
set -euo pipefail
cd "$(dirname "$0")/.."
# shellcheck disable=SC1091
source ../.elixir-env
export DB_DATABASE="${TEST_DATABASE:-lineage_remastered_test}"
# Its own build tree. Both servers are MIX_ENV=dev, and this one recompiles on startup — sharing
# _build/dev would swap .beam files under a running dev server that has code reloading on.
export MIX_BUILD_ROOT=_build_e2e
# Its own port, so it can never silently answer for a dev server already on 4000.
export PORT="${E2E_PORT:-4002}"

mix ecto.migrate >/dev/null
exec mix phx.server
