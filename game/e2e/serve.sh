#!/usr/bin/env bash
# Serves the app against an isolated database, so a browser walkthrough — which creates
# characters, spends adena and submits highscores — never touches the real dev data.
set -euo pipefail
cd "$(dirname "$0")/.."
# shellcheck disable=SC1091
source ../.elixir-env
export DB_DATABASE="${E2E_DATABASE:-lineage_remastered_dev_b}"
# Its own port, so it can never silently answer for a dev server already on 4000.
export PORT="${E2E_PORT:-4002}"
exec mix phx.server
