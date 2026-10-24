# ⚔️ Mini-Lineage Remastered

A text-based RPG in the spirit of Lineage II, rebuilt in Elixir, Phoenix LiveView and OTP, with a
dark fantasy interface that updates in real time.

Today it is the base layer (who a character is and the numbers that make them) and the first hunt:
each village's ground, its traders and guild, the inventory, death and the Halls. The game as it was
before is kept to be read in [`legacy/`](legacy/README.md), and what is not back yet (the Tome, a
run's Chronicle, classes, dyes) returns one system at a time, built on the rules, as
[`docs/roadmap.md`](docs/roadmap.md) lays out; why the game is shaped as it is lives in
[`docs/direction.md`](docs/direction.md). Every
Lineage II name and number in the game comes from the canon in [`docs/canon/`](docs/canon/README.md),
checked against Interlude's own data.

## 🎮 The game

- **Four lineages, two paths.** Humans, Orcs, Elves and Dark Elves, each a Fighter or a Mystic: eight
  starting sets of six attributes. All of it is in [`docs/rules.md`](docs/rules.md), with a worked
  example for every rule, and `rules_test.exs` holds the code to it.
- **Each race starts at home** in its own village. A 🌀 Gatekeeper in every town sends you along a
  route for Adena. The villages link to the 🏰 Town of Gludio, and the mainland goes on to Dion.
- **Day and night.** From 22:00 to 06:00 on the game's clock (UTC unless `TIME_ZONE` sets another),
  a 🌙 aura costs every character 3 Accuracy.
  Dark Elves win it back, and Elves rest faster under the Mother Tree.
- **Stats that grow with you**, worked from the attributes and the level up to level 80, on L2's own
  EXP table.
- **One click, one fight.** Each village has its hunting ground outside, a ladder of its own canon
  monsters. The last fight fought there is drawn under the ground in its 📜 Fight Log, a round a
  row with where both sides stand, its criticals washed orange and its heals green, kept in
  `encounters` so a reload finds it. A death is final: the run stays on the ground it fell on as a
  👻 ghost under 🪦 Game Over, its fight ending in Defeat, until you play again, and its row stays
  on the 🏛️ Monument of Heroes at `/highscores` with how long ago it fell.
- **Traders and a bag.** Each village's weapon, armour and magic traders sell your path's own goods,
  and buy back for half; the inventory at `/inventory` equips, drinks and destroys, and potions are
  drunk in a fight below the share the 🎖️ Battle Orders under the ground set, on a slider shown
  while you carry one, beside a switch for each skill.
- **Every set fights its own way.** Its trainer at home teaches a short list from its own Lineage II
  tree for the SP of the hunt: the Human Fighter has a skill for every weapon, the Elven Fighter
  guards with Defense Aura, the Dark Fighter strikes with Attack Aura, the Orc Fighter rests with
  Relax, and each Mystic has its own spells. A skill grows in a few big steps rather than nine
  small ones. Auras hold 2 minutes and go up before the pull. Three masteries a path (Armor or Robe,
  Weapon, Anti Magic) are there to learn or skip, as the monsters met make worth it. The guild is at
  `/<village>/guild`, its lessons on an Active and a Passive shelf.
- **Rest mends, and says so.** While HP or MP is short, 🌿 *Regenerating* shows what a 3-second tick
  mends, and the tick mends it. The aura and the mending are one condition, so neither appears
  without the other.
- **The page shows what the fight works out, never the formula.** Speed and a shield's Block sit
  among the Combat Stats; a skill says what it mends, how often it lands, its cast and its reuse,
  for this character; a buff reads "+8% P. Def.", as Lineage II's data writes it. Every buff, and the
  wait before rest after a hunt, counts down over its icon as the legacy game's did.
- **A sidebar** under a vital panel drawn like L2's status window, its HP or MP row pulsing once under a quarter,
  a character page at `/character`, and the Chronicles of Ancestry at `/races`, which tell every
  lineage before you choose one.
- **What an action says is coloured by what it did**: green for something gained, blue for a
  rearrangement, red for a refusal, and gold, shining, for a new level.
- **Figures count, they don't jump**, five 8-bit sounds made by a Web Audio synth (a new game, a
  success, a new level, a death, the sound toggle), and play from the keyboard alone.

## 🛠️ Tech stack

- **Elixir 1.20 on OTP 29**, served by Bandit; **Phoenix 1.8 with LiveView 1.2**: server-rendered
  HTML over one WebSocket, with no client-side framework
- **One `GenServer` per character** under a `DynamicSupervisor` + `Registry`, with `Phoenix.PubSub`
  keeping tabs in sync
- **PostgreSQL 18** through Ecto, each character one `jsonb` document in `characters`, its
  inventory in `items` and every fight it fought in `encounters`
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
mix ecto.migrate        # on a new database; `mix dev` doesn't migrate. Until `next` is first
                        # deployed the schema is one migration, so a change to it is a rebuild
                        # (AGENTS.md, Data)
```

### Debug-build shortcuts

In dev and the e2e server, never in a release, keys typed outside a text field drive a few
shortcuts. Any other key between two letters breaks a word.

| Type | What it does |
|---|---|
| `adena` | 10,000 Adena into the purse |
| `sp` | 10,000 SP, to try the trainer |
| `night` / `day` | holds the whole server at that hour for five minutes, or until the other word |
| `half` | HP and MP to half, and the XP bar halfway to the next level |
| `frail` | 1 HP, so the next fight can end the run |
| `lvl` / `maxlvl` | exactly the EXP for the next level, or for level 80 |
| Ctrl+Q | deletes the character (Firefox on Linux quits instead) |

Game start also comes with a random name already written in, so trying another race is one click.

### Development tools

Both are `:dev` only and neither changes the CSP.
[LiveDebugger](https://github.com/software-mansion/live-debugger) runs on <http://localhost:4007>
and shows every LiveView's assigns and callbacks. Its assigns include the session id, which signs in
as that character, so don't share screenshots of it.
[Tidewave](https://github.com/tidewave-ai/tidewave_phoenix) gives a coding agent the running app over
MCP; `.mcp.json` points Claude Code at `http://localhost:4000/tidewave/mcp`.

### The browser suites

- **`e2e/walkthrough.mjs`** plays one character end to end: the CSP, the cookie, the error page,
  creation from the keyboard, the sidebar and character page, a second tab, the Gatekeeper, the Halls,
  the hunt, the traders and inventory, potions, the guild, the battle orders, every dropdown held
  open across a tick, and every debug shortcut, then, in a browser of its own, a death and Play
  Again. It fails on any failed request or console error.
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
`DB_PASSWORD`, `PORT` and `LOG_LEVEL` have defaults; see [.env.example](.env.example). The server
rates, `EXP_RATE`, `SP_RATE` and `ADENA_RATE`, default to retail's ×1; set them to rules §22's
private ×5, ×5 and ×20, as `.env.example` does, or the game plays far slower than it was tuned for.
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
