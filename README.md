# ⚔️ Mini-Lineage Remastered

**Mini-Lineage Remastered** is a modern rewrite of the classic text-based RPG. Built with Elixir,
Phoenix LiveView and OTP, it revitalizes the nostalgic gameplay loop with real-time state
synchronization, procedural 8-bit audio synthesis, and an aesthetic dark fantasy user interface.

## 🌟 Key Features
### 🎮 Gameplay & Combat
- **Four Lineages**: **Humans**, **Orcs**, **Elves** and **Dark Elves**, each with its own starting health, purse, critical chance, ambush risk and HP regeneration, and a fixed rival race it fights all run.
- **Scaled Combat**: Weapon Attack drives enemy party size, XP and Adena; Armor Defense mitigates damage *sub-linearly*, so stacking armor never reaches invincibility.
- **Punchy Critical Strikes**: A `1.9×` critical multiplier applied to enemies slain, XP, and Adena alike, so a crit stays impactful at every attack tier.
- **Chain Ambush Engine**: Every fight rolls a fresh ambush against your live ambush risk. Two consecutive ambushes inflict the `Hexed` debuff (`+4% Ambush Risk`, `-2% Crit`, 1 minute), snowballing the danger for reckless adventurers.
- **Equipment & Progression**: 6 weapon tiers and 6 armor tiers, the top ones carrying innate modifiers (*Calamity Comet*'s crit, *Eternal Aegis*' regen), across a level curve that runs to **level 80**.
- **Playable Without a Mouse**: The panel's first control takes focus on arrival, so <kbd>Space</kbd> fights on the Battleground and <kbd>↑</kbd><kbd>↓</kbd> + <kbd>Enter</kbd> drives travel and the shops. Pressing a button hands focus to whatever answers — buying gives it back to the picker — while a control you moved to yourself is left alone. The death screen takes no focus and releases any it inherits, so the <kbd>Space</kbd> that fought cannot submit a score unread.

### 🎧 Procedural 8-Bit Web Audio Engine
- **Zero Audio Assets**: 100% synthesized in real time via the browser's native `AudioContext`, `OscillatorNode`, and `GainNode`.
- **Event-Driven Soundscapes**: Seven declaratively-defined voices — Game Start, Critical Hit, Ambush Alarm, Level Up Fanfare, Inn Dining, Shop Purchase, and Death.
- **Gesture-Safe Unlock**: A single capture-phase pointer/keyboard listener resumes the `AudioContext` on the very first user interaction — sounds fire from socket-ack handlers, not DOM markers, so nothing ever races a reload.
- **Client Mute Controls**: Persistent audio toggle stored in `localStorage` with non-blocking UI controls.

### ⚡ Real-Time Engine & Zones
- **Server-Side Tick Cadence**: A 5-second tick loop applies passive HP regeneration and sweeps expired buffs/debuffs, alongside exact per-effect timers so an expiry fires to the millisecond rather than waiting for the next tick.
- **Location-Based Zones**: The server classifies the reported screen as combat (Battleground, Suicide, Death — regeneration pauses) or resting (everywhere else). Being *ambushed* forces combat whatever the client claims, so a raw socket client cannot lie its way out of one.
- **Disengaging Takes Five Seconds**: Leaving combat keeps ⚔️ *In Combat* for a 5-second countdown before 💤 *Resting* resumes regeneration. Standing in a combat zone keeps the flag indefinitely, so waiting on the Battleground never heals; stepping back in cancels the countdown.
- **Regeneration Is Earned, Not Assumed**: 🌿 *Regenerating* is derived per snapshot rather than stored, so it appears and vanishes on its own: it needs the resting aura, a wound, and a positive HP-regen rate at once. An Orc (no innate regen) never sees it; a player at full health loses it the instant they top up.
- **Non-Mutating Reads**: Connecting, reconnecting and refreshing only *read* state. A fight happens only on an explicit `battle:fight`, never on page load, so navigating away mid-ambush escapes nothing.
- **LiveView Streaming**: One WebSocket carries the whole game. The server diffs the rendered HTML and pushes only what changed, with no page reloads. Multiple tabs on one session stay in sync over `Phoenix.PubSub`.

### 🍖 Inn & Consumables
- **Tiered Meals**: Five dishes from *Spiced Ale* to *Roasted Pheasant*. All restore HP; the top three also grant a timed buff (*Satisfied*, *Well Fed*, *Gourmet Feast*) that temporarily expands the maximum health pool. Only one food buff is active at a time — a new meal replaces the old one.

### 🏆 Leaderboards & Statistics
- **Live Leaderboards**: The top 25 adventurers ordered by total Experience, then Adena — filterable per race. Cowards and cheaters are barred from posting.
### 🛡️ Security & Reliability
- **One Place For Every Access Rule**: `Access.pin_screen/2` decides where a player may be, and every navigation funnels through `handle_params/3`, so an in-app link, a typed URL and the Back button obey the same checks. The dead are confined to the death screen and the living kept off it; a player with a character cannot re-enter character creation; an ambushed one is pinned to the Battleground. The game owns every URL — an unrecognised path resolves to Town.
- **Guarded Mutations**: Every event that changes state declares its own preconditions, enforced server-side. Client-side routing is convenience; these guards are the boundary. Notably restarting requires a *dead* character, so a living one can never be wiped.
- **A Process Per Character, Not A Lock**: Each character is a `GenServer` under a `DynamicSupervisor`, addressed through a `Registry`. The mailbox serialises, so concurrent actions on one session cannot interleave into a lost update.
- **Revision-Guarded State**: Every persisted mutation bumps a monotonic `revision`, so a stale push can never clobber fresher state.
- **Security Hardening**: A CSP with no inline scripts, `httpOnly`/`sameSite` session cookies, validation on every payload, and sliding-window rate limiting (60 battles and 30 shop actions per minute, plus a 300/min flood limiter). Rate limits are bypassed outside a release build so local development isn't throttled.
- **Idle Characters Are Reaped**: A character process arms a stop timer at start and cancels it when a viewer attaches, so a crawler leaves nothing running. Rows outlive the process and are swept after 30 days, the window the session cookie uses.

## 🛠️ Tech Stack

- **Runtime**: Elixir 1.19 on OTP 28, served by Bandit
- **Web**: Phoenix 1.8 with LiveView 1.1 — server-rendered HTML over one WebSocket, no client-side framework and no client-side router
- **Concurrency**: One `GenServer` per character under a `DynamicSupervisor` + `Registry`; `Phoenix.PubSub` for multi-tab sync; `Process.send_after/3` for the 5-second tick and for exact per-effect expiry
- **Database**: Ecto + MyXQL against MariaDB, with each character persisted as a single JSON document
- **Audio Engine**: Web Audio API (procedural synthesizer), driven from a LiveView JS hook
- **Testing**: ExUnit, plus two Playwright suites that drive a real headless Chromium

Requires **Elixir 1.19+ on OTP 28+**, and a reachable MariaDB or MySQL.

## Running it

Once, ever:

```bash
grep -q 'mini-lineage-remastered/env.sh' ~/.bashrc \
  || echo '[ -f ~/mini-lineage-remastered/env.sh ] && source ~/mini-lineage-remastered/env.sh' >> ~/.bashrc
exec bash                   # or just open a new terminal

cd ~/mini-lineage-remastered
mix setup                   # deps, database, assets, and the test browser
```

After that, every terminal already has what it needs and there is nothing to source:

```bash
mix                         # the game, on http://localhost:4000
mix e2e                     # the browser suites, server and all
```

There is no root on this machine, so Elixir, the ERTS libraries, Chromium's libraries and Node
all live under `~/.local` and `~/.nvm`. `env.sh` puts them on the PATH. It is safe to source
twice, and the repo's scripts source it themselves, so they work either way.

To keep an IEx shell attached while it runs:

```bash
iex -S mix phx.server
```

### Why there is an npm as well as a mix

npm downloads Playwright and the Chromium it drives, and nothing else. It builds nothing: the
JavaScript and CSS are bundled by esbuild, which is an **Elixir** package, so `mix assets.build`
needs no Node.

`mix setup` runs `npm ci` for you. `npm run test:e2e` forwards to `mix e2e`, so there is one way
in, not two.

## Which database

| what | database | from | port |
|---|---|---|---|
| `mix phx.server` | your real characters, highscores and statistics | `DB_DATABASE` | `PORT` (4000) |
| `mix test` | a throwaway one | `DB_DATABASE_TEST` | — |
| `mix e2e` | the same throwaway one, board emptied first | `DB_DATABASE_TEST` | `PORT_E2E` (4002) |

An unreleased build names itself in the footer — `⚡ development` on 4000, `🔥 testing` on 4002 —
so the two are never confused. A release names its commit instead.

Settings come from the repo-root `.env` — see [.env.example](.env.example) for what each one does.
A real environment variable always beats the file, which is how `e2e/serve.sh` and CI override it.
`config/runtime.exs` reads it at BOOT, so a release started with `bin/mini_lineage start` picks up
the same file rather than needing every variable on the command line; it looks in the working
directory, and `ENV_FILE` names it elsewhere.

Both servers can run at once — the browser suites have their own port and their own database
precisely so they can create characters, spend adena and submit highscores without touching real
data. They empty that database's board before each run, through `e2e/reset.sh`, which refuses any
database not named for a test.

## Commands

```bash
mix                     # run the game            (:4000, real dev data)
mix dev                 # ...the same thing, said out loud
mix prod                # test, build, migrate, serve — `mix build` then `mix start`
mix build               # test and build a release, without serving it
mix start               # migrate and serve a release already built
mix stop                # stop a release that is still running

mix test                # the Elixir suite
mix test.coverage       # ...with a coverage report
mix e2e                 # both browser suites — see below
mix e2e walkthrough     # ...one character, played normally
mix e2e races           # ...every lineage

mix ecto.migrate        # apply pending migrations
mix ecto.migrations     # what is applied
mix ecto.reset          # drop everything and rebuild it (destructive)

mix format
mix compile --warnings-as-errors
mix precommit           # compile --warnings-as-errors, deps.unlock, format, test
mix balance             # the balance simulations — see below
```

`mix dev` does not migrate: that is a deployment step, and `mix start` does it. Run
`mix ecto.migrate` yourself after pulling a schema change.

**Ctrl-C does not stop the server `mix start` and `mix prod` launch** — Erlang puts it in its own
process group, beyond this terminal's interrupt. Use `mix stop`. If you forget, `mix dev` and
`mix start` say so by name rather than failing on `:eaddrinuse`.

`mix test.coverage` reports, it does not gate. The browser suites exercise the web layer and are
not instrumented, so the number understates what is covered.

## Balance simulations

Ten studies that measure the balance. They read the shipped constants, so a rebalance is
re-measured by rerunning them rather than by editing them.

```bash
mix balance                 # list them
mix balance crit_balance    # run one
mix balance all             # run every one
```

They compile only in `:dev`, so no release carries them.

## Building a release

One command does the whole thing — tests, dependencies, assets, the release, pending migrations,
then the server in the foreground:

```bash
mix prod          # = mix build && mix start
```

**It stops at the first failing test and deploys nothing.**

To do it by hand instead — nothing here needs a database or a secret, since `config/runtime.exs`
is read at boot rather than at build:

```bash
MIX_ENV=prod mix deps.get --only prod
MIX_ENV=prod mix assets.deploy      # compile, esbuild --minify, then phx.digest
MIX_ENV=prod mix release
```

Set `MIX_ENV` per command, not with `export` — an exported one follows you into `mix test`, which
then fails complaining about the pool.

The release reads `.env` at boot, so from the repo root this is the whole of running it:

```bash
_build/prod/rel/mini_lineage/bin/mini_lineage eval 'MiniLineage.Release.migrate()'
PHX_SERVER=true _build/prod/rel/mini_lineage/bin/mini_lineage start
```

`.env` is looked for in the **working directory**; `ENV_FILE` names it anywhere else. A real
environment variable always beats the file.

If a migration has to come back out, the same binary rolls it back:

```bash
bin/mini_lineage eval 'MiniLineage.Release.rollback(MiniLineage.Repo, 20260906000002)'
```

The build stamps itself with `git rev-parse --short=7 HEAD` and the footer links that commit.
`APP_VERSION` overrides it, in the seven-character form, and is required wherever the build has no
checkout to ask — a Docker build, or CI. A build that can supply neither refuses to build.

A release carries no Mix, so migrations go through `MiniLineage.Release`. Name the database with
the `DB_*` keys or with a single `DATABASE_URL`; the parts win when both are set.

Production differs from development: rate limiting is **on** (60 battles and 30 shop actions per
minute, 300 events/min overall), `force_ssl` redirects to `https://$PHX_HOST` for every host but
`localhost` and `127.0.0.1`, the logger sits at `:info`, and there is no code reloader.

## Docker

`Dockerfile` builds the release on the same Elixir and OTP this is developed against, then ships
it on bare Alpine with no Elixir or Mix — the release brings its own ERTS. It provisions no
database of its own, so point `DB_HOST` at one the container can reach.

`docker-compose.yml` pulls the published image and has no `build:` section, so a deployment can
only ever run what CI built. The container migrates before it serves, so a fresh database is never
served against.

### Building and running it standalone

The image needs nothing from compose or Portainer. Build it, then run it:

```bash
docker build --build-arg APP_VERSION=$(git rev-parse --short=7 HEAD) -t mini-lineage .

docker run --rm -p 4000:4000 --env-file .env \
  --add-host host.docker.internal:host-gateway \
  -e DB_HOST=host.docker.internal \
  mini-lineage
```

Three things decide whether that works:

- **`DB_HOST` must be reachable from inside the container.** `127.0.0.1` there is the container
  itself, not your machine — hence the `--add-host`/`-e` pair above. A database on another host
  needs neither.
- **`--env-file` is Docker's own parser, not this app's.** It does not strip a comment written
  after a value, so `PHX_HOST=localhost # the domain` would set the hostname to the whole line.
  `.env.example` keeps every comment on its own line for exactly this reason. To use this app's
  parser instead, mount the file at the working directory the release reads it from:
  `-v "$PWD/.env:/app/.env:ro"`. The container runs as a non-root user, so that file has to be
  readable by others — a `chmod 600 .env` makes the mount fail where `--env-file` would not.
- **Keep `PHX_HOST=localhost` for a local run.** With a real domain, `force_ssl` answers every
  plain-http request with a redirect to it; `localhost` and `127.0.0.1` are the excluded pair.

The build **requires** `APP_VERSION` and refuses without one, so that no image can be running
without being able to say which commit it is. For a throwaway image any seven characters will do.

### Deploying

CI publishes the image, so a server pulls rather than builds:

    ghcr.io/sunny-azu-red/mini-lineage-remastered:latest

The `publish` job runs only from `main` and only behind both green jobs, so what is deployed is
the artifact that passed. It verifies the commit stamp inside the image before pushing. Every
image is tagged twice, `latest` and its seven-character commit, so `IMAGE_TAG` pins or rolls back
to any of them; unset, it follows `main`.

The image is built for **amd64 only**. On an ARM host the pull fails, and `platforms:` in the
publish job is where that changes.

Two things to do once, on the package's page in GitHub: make it **public**, or Portainer will need a
registry credential to pull it; and, if you want, link it to the repository. Then point the stack at
this compose file and redeploy with **Re-pull image** on.

The footer names the commit the running build came from, which is how you tell a deploy took: it
links the commit, or says `⚡ development`. There is no third answer.

CI supplies it as `APP_VERSION`. A build from a checkout finds its own, which is why the
Dockerfile takes a build arg rather than reading a `.git` a Portainer stack does not send.

**Put TLS in front of it.** With a real `PHX_HOST`, `force_ssl` 301s every plain-http request to
`https://$PHX_HOST`: right behind a proxy that terminates TLS and sets `X-Forwarded-Proto`, a
redirect loop if exposed directly on port 80. `localhost` and `127.0.0.1` are excluded, which is
how the compose healthcheck reaches the game.

The image also sets `LANG=C.UTF-8` (the VM otherwise runs latin1, and this game is made of
emoji), `ca-certificates` for a database reached over TLS, and `init: true`, since the release
runs as PID 1 and does not reap what the ERTS spawns.

## The browser suites

Two Playwright runs drive a real headless Chromium, sharing their controls through
`e2e/helpers.mjs`:

- **`e2e/walkthrough.mjs`** — one character played normally, end to end: create, travel, buy,
  fight, die, submit a highscore, restart. It asserts that no request failed, no console error was
  logged, a background tick disturbs neither the main panel nor an open `<select>`, focus lands
  where the keyboard needs it, and the audio synth builds the graph it should.
- **`e2e/races.mjs`** — every lineage played through: each one's purse, health and stats as the
  screens show them, what it can afford at birth, and its road to the board. With all four on the
  highscore board it can check something one race cannot — that every filter narrows to rows of
  that race alone.

Both empty the board first, through `e2e/reset.sh`, which refuses any database not named for a
test.

One command, one terminal:

```bash
mix e2e                 # both, about a minute
mix e2e walkthrough     # just the first
```

It starts the isolated server, empties the board, drives Chromium, and stops the server it
started. A server already running on that port is used as it is and left alone, so
`e2e/serve.sh` in another terminal works too.

One run at a time: they share a database and each empties the board first, so a second `mix e2e`
refuses and names the one already going.

Neither suite asserts on a roll of the dice — a browser cannot seed the generator. They drive the
situations they need, then check what only a browser can see. What the dice decide is pinned in
`test/mini_lineage/game/balance_golden_test.exs`.

## 📜 License

MIT — see [LICENSE](LICENSE). © 2026 Sunny
