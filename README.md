# ⚔️ Mini-Lineage Remastered

A text-based RPG in the spirit of Lineage II, rebuilt in Elixir, Phoenix LiveView and OTP, with a
dark fantasy interface that updates in real time.

For now it is cut back to its base layer: who a character is and the numbers that make them. The
game as it was before (the Inn and the shops, the Battleground, the Halls, the Tome, a run's record
and its Chronicle) is kept to be read in [`legacy/`](legacy/README.md). Each of those systems comes
back one at a time, built on the rules, as [`docs/roadmap.md`](docs/roadmap.md) lays out.

## 🎮 The game

- **Four lineages, two paths.** Humans, Orcs, Elves and Dark Elves, each a Fighter or a Mystic: eight
  starting sets of six attributes. All of it is in [`docs/rules.md`](docs/rules.md), with a worked
  example for every rule, and `rules_test.exs` holds the code to it.
- **Each race starts at home** in its own village. A 🌀 Gatekeeper in every town sends you along a
  route for Adena. The villages link to the 🏰 Town of Gludio, and the mainland goes on to Dion.
- **Day and night.** From 22:00 to 06:00 Bucharest time, a 🌙 aura costs every character 3 Accuracy.
  Dark Elves win it back, and Elves rest faster under the Mother Tree.
- **Stats that grow with you**, worked from the attributes and the level up to level 80, on L2's own
  EXP table.
- **Rest heals, and says so.** While HP or MP is short, 🌿 *Regenerating* shows, and a 3-second tick
  heals. The aura and the healing are one condition, so neither appears without the other.
- **A status sidebar** drawn like L2's status window, a character page at `/character`, and the
  Chronicles of Ancestry at `/races`, which tell every lineage before you choose one.
- **Figures count, they don't jump**, two 8-bit sounds made by a Web Audio synth, and play from the
  keyboard alone.

## 🛠️ Tech stack

- **Elixir 1.20 on OTP 29**, served by Bandit; **Phoenix 1.8 with LiveView 1.2**: server-rendered
  HTML over one WebSocket, with no client-side framework
- **One `GenServer` per character** under a `DynamicSupervisor` + `Registry`, with `Phoenix.PubSub`
  keeping tabs in sync
- **PostgreSQL 18** through Ecto, each character one `jsonb` document in one table
- **ExUnit** with StreamData properties, and **Playwright** suites driving headless Chromium

How the code is meant to be written, and why, is in [AGENTS.md](AGENTS.md) and
[docs/design.md](docs/design.md).

## 🚀 Running it

You need Elixir and OTP as above, a reachable PostgreSQL, and Node at the version `.nvmrc` pins
(Playwright only; `nvm install` picks it up). The browser suites also use `curl`, `ss`, `ps` and
`pkill`.

```bash
# once
echo '[ -f ~/mini-lineage-remastered/env.sh ] && source ~/mini-lineage-remastered/env.sh' >> ~/.bashrc
exec bash
cp .env.example .env               # fill in your database
cp .env.test.example .env.test     # and a throwaway one for tests
mix setup                          # deps, database, assets, the test browser
mix test                           # also creates the throwaway database

# every day
mix                                # the game, on http://localhost:4000
mix e2e                            # the browser suites, server and all
```

There is no root on the dev machine, so the toolchain lives under `~/.local` and `~/.nvm`, and
`env.sh` puts it on the PATH. npm only fetches Playwright and Chromium: assets are built by esbuild,
an Elixir package.

### Which database

| what | database | reads | port |
|---|---|---|---|
| `mix` | your real characters | `.env` | 4000 |
| `mix test` | a throwaway one | `.env.test` | none |
| `mix e2e` | the same throwaway one, emptied first | `.env.test` | 4002 |

Both servers can run at once. `e2e/reset.sh` refuses to empty whichever database `.env` names. A real
environment variable always beats the file. The footer tells the builds apart: `🔥development`,
`🍃testing`, or a release's commit.

### Commands

```bash
mix                     # run the game (same as `mix dev`)
mix test                # the Elixir suite (`mix test.coverage` reports, never gates)
mix e2e [walkthrough|races]   # the browser suites, or one of them
mix precommit           # warnings as errors, unused deps, format, test

mix prod                # test, build a release, migrate, serve (= mix build && mix start)
mix stop                # stop it; Ctrl-C can't reach a release
mix ecto.migrate        # after pulling a schema change; `mix dev` doesn't migrate
```

### Debug-build shortcuts

In dev and the e2e server, never in a release, keys typed outside a text field drive a few
shortcuts. Any other key between two letters breaks a word.

| Type | What it does |
|---|---|
| `adena` | 10,000 Adena into the purse |
| `night` / `day` | holds the whole server at that hour until the other word or a restart |
| `half` | HP and MP to half, and the XP bar halfway to the next level |
| `lvl` / `maxlvl` | exactly the EXP for the next level, or for level 80 |
| Ctrl+Q | deletes the character (Firefox on Linux quits instead) |

### Development tools

Both are `:dev` only and neither changes the CSP.
[LiveDebugger](https://github.com/software-mansion/live-debugger) runs on <http://localhost:4007>
and shows every LiveView's assigns and callbacks. Its assigns include the session id, which signs in
as that character, so don't share screenshots of it.
[Tidewave](https://github.com/tidewave-ai/tidewave_phoenix) gives a coding agent the running app over
MCP; `.mcp.json` points Claude Code at `http://localhost:4000/tidewave/mcp`.

### The browser suites

- **`e2e/walkthrough.mjs`** plays one character end to end: the CSP, the cookie, the error page,
  creation from the keyboard, the sidebar and character page, a second tab, the Gatekeeper, and
  every debug shortcut. It fails on any failed request or console error.
- **`e2e/races.mjs`** makes every starting set and checks each against `docs/rules.md`.
- **`e2e/release.mjs`** makes a character against a built image, under `e2e/release.sh`.

`mix e2e` migrates, starts an isolated server, drives Chromium and stops the server. It reuses one
already on the port only if it is newer than every source file, and refuses to run twice at once.

## 📦 Releases and deployment

```bash
MIX_ENV=prod mix deps.get --only prod
MIX_ENV=prod mix assets.deploy
MIX_ENV=prod mix release
_build/prod/rel/mini_lineage/bin/mini_lineage eval 'MiniLineage.Release.migrate()'
PHX_SERVER=true _build/prod/rel/mini_lineage/bin/mini_lineage start
```

Set `MIX_ENV` per command rather than exporting it, or it follows you into `mix test`. The release
reads `.env` from its working directory at boot, or wherever `ENV_FILE` names. To roll a migration
back, along with every migration after it:
`bin/mini_lineage eval 'MiniLineage.Release.rollback(MiniLineage.Repo, <version>)'`.

The build stamps itself with `git rev-parse --short=7 HEAD`. Where there is no checkout (Docker, CI)
`APP_VERSION` must supply it, and a release that has neither refuses to build.

**A deployment must set** `PHX_HOST`, `SECRET_KEY_BASE` (64+ bytes, from `mix phx.gen.secret`) and
the database, as `DB_DATABASE` or `DATABASE_URL`. `DB_HOST`, `DB_PORT`, `DB_USERNAME`,
`DB_PASSWORD`, `PORT` and `LOG_LEVEL` have defaults; see [.env.example](.env.example).
- `PHX_HOST` is also the only origin the LiveView socket accepts. Name it wrongly and the page renders
  once and never connects, with nothing in the log.
- `force_ssl` redirects plain HTTP to HTTPS on every host but `localhost` and `127.0.0.1`. Put a proxy
  that terminates TLS and sets `X-Forwarded-Proto` in front of it.
- Anything read through `compile_env` is fixed when the image is built, and a release refuses to
  start if the environment disagrees.

### Docker

The `Dockerfile` builds the release and ships it on bare Alpine. It brings no database.

```bash
docker build --build-arg APP_VERSION=$(git rev-parse --short=7 HEAD) -t mini-lineage .
docker run --rm --init -p 4000:4000 --env-file .env \
  --add-host host.docker.internal:host-gateway -e DB_HOST=host.docker.internal mini-lineage
```

- Inside the container, `127.0.0.1` is the container itself, hence the `--add-host` pair.
- `--env-file` keeps a comment written after a value as part of it. Keep comments on their own lines,
  or mount the file at `/app/.env:ro` (readable by others, since the container isn't root).
- Keep `PHX_HOST=localhost` for a local run.

**`e2e/release.sh`** checks an image the way a deployment runs it: it builds the image as CI does,
starts the real `docker-compose.yml` against an empty Postgres 18, waits for the healthcheck and the
migration, checks the socket's origin both ways, and makes a character. CI runs it before every push.

Without root, install the [rootless Engine](https://get.docker.com/rootless) (read it, then `sh` it),
and put the buildx and compose release binaries, checked against their published checksums, in
`~/.docker/cli-plugins/` as `docker-buildx` and `docker-compose`.

### Deploying

CI publishes `ghcr.io/sunny-azu-red/mini-lineage-remastered`, from `main` only and only after the
tests and `e2e/release.sh` pass, tagged `latest` and with its short commit, which `IMAGE_TAG` pins.
It is amd64 only. `docker-compose.yml` has no `build:` section, so a server only runs what CI built,
and the container migrates before it serves. Make the package public so Portainer can pull it, then
redeploy with **Re-pull image** on. The footer names the commit that is running.

## 📜 License

MIT, see [LICENSE](LICENSE). © 2026 Sunny
