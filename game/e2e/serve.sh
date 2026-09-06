#!/usr/bin/env bash
# Serves the app against an isolated database, so a browser walkthrough — which creates
# characters, spends adena and submits highscores — never touches the real dev data.
set -euo pipefail
cd "$(dirname "$0")/.."
# shellcheck disable=SC1091
source ../.elixir-env
export DB_DATABASE="${TEST_DATABASE:-lineage_remastered_test}"
# Its own MIX_ENV, so the build lands in the already-ignored _build/e2e rather than under the dev
# server someone may be playing on. config/e2e.exs is just the dev configuration.
export MIX_ENV=e2e
# Its own port, so it can never silently answer for a dev server already on 4000.
export PORT="${E2E_PORT:-4002}"

mix ecto.migrate >/dev/null
exec mix phx.server
