#!/usr/bin/env bash
# The release cycle as a deployment sees it: the image, compose, an empty Postgres, a browser.
# CI's publish job runs this on the image it is about to push, so a local run is that run.
#
#   e2e/release.sh                        build as CI does, then check it
#   IMAGE=… APP_VERSION=… e2e/release.sh  check an image already built
set -euo pipefail
cd "$(dirname "$0")/.."

for need in "docker" "docker buildx version" "docker compose version"; do
  $need >/dev/null 2>&1 || { echo "missing: $need (see AGENTS.md, Docker)" >&2; exit 1; }
done

APP_VERSION=${APP_VERSION:-$(git rev-parse --short=7 HEAD)}
PORT=${RELEASE_PORT:-4100}
BASE="http://localhost:$PORT"

if [ -z "${IMAGE:-}" ]; then
  IMAGE="mini-lineage:check"
  docker buildx build --load --build-arg "APP_VERSION=$APP_VERSION" -t "$IMAGE" .
fi

# A missing stamp is silent: the footer shows nothing rather than failing.
docker run --rm --entrypoint sh "$IMAGE" \
  -c 'grep -q "$1" "releases/$(cut -d" " -f2 releases/start_erl.data)/sys.config"' sh "$APP_VERSION" \
  || { echo "image does not report $APP_VERSION" >&2; exit 1; }
echo "stamped $APP_VERSION"

work=$(mktemp -d)
project="mlrelease$$"
# Compose reads ./.env for interpolation, which names the real database: hand it a file of its own.
# The override swaps only the image and adds the database; everything else is the deployment's.
cat >"$work/check.env" <<EOF
PORT=$PORT
PHX_HOST=localhost
SECRET_KEY_BASE=$(head -c 48 /dev/urandom | base64 -w0)$(head -c 48 /dev/urandom | base64 -w0)
DB_HOST=db
DB_DATABASE=lineage_release
DB_USERNAME=postgres
DB_PASSWORD=pass
EOF
cat >"$work/compose.check.yml" <<EOF
services:
  mini-lineage:
    image: $IMAGE
    pull_policy: never
    container_name: $project-game
    depends_on:
      db: { condition: service_healthy }
  db:
    image: postgres:18
    environment: { POSTGRES_PASSWORD: pass, POSTGRES_DB: lineage_release }
    healthcheck: { test: ["CMD", "pg_isready", "-U", "postgres"], interval: 2s, retries: 30 }
EOF
compose=(docker compose -p "$project" -f docker-compose.yml -f "$work/compose.check.yml" --env-file "$work/check.env")
cleanup() { "${compose[@]}" logs mini-lineage >"$work/game.log" 2>&1 || true
            "${compose[@]}" down -v >/dev/null 2>&1 || true; }
trap 'status=$?; cleanup; if [ $status -ne 0 ]; then cat "$work/game.log"; fi; rm -rf "$work"' EXIT

"${compose[@]}" up -d
# The compose healthcheck itself, so a probe that cannot reach the game fails here first.
for _ in $(seq 1 60); do
  health=$(docker inspect -f '{{.State.Health.Status}}' "$project-game")
  [ "$health" = healthy ] && break
  sleep 2
done
[ "$health" = healthy ] || { echo "the game never reported healthy ($health)" >&2; exit 1; }
"${compose[@]}" logs mini-lineage | grep -q "Migrated" || { echo "no migration ran on boot" >&2; exit 1; }

expect() { [ "$2" = "$3" ] || { echo "$1: got $2, wanted $3" >&2; exit 1; }; echo "ok $1"; }
expect "GET /" "$(curl -s -o /dev/null -w '%{http_code}' "$BASE/")" 200
expect "GET /health" "$(curl -s -o /dev/null -w '%{http_code}' "$BASE/health")" 200
expect "an unknown path is a 404" "$(curl -s -o /dev/null -w '%{http_code}' "$BASE/no-such-road")" 404
# check_origin fails without a word: the page loads and never connects.
upgrade() { curl -s -o /dev/null -w '%{http_code}' --max-time 5 -H "Origin: $1" \
  -H 'Connection: Upgrade' -H 'Upgrade: websocket' -H 'Sec-WebSocket-Version: 13' \
  -H 'Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==' "$BASE/live/websocket?vsn=2.0.0" || true; }
expect "the socket takes PHX_HOST's origin" "$(upgrade "$BASE")" 101
expect "...and refuses another" "$(upgrade "http://evil.example")" 403

E2E_BASE_URL=$BASE APP_VERSION=$APP_VERSION node e2e/release.mjs
