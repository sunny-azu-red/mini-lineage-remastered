# ⚔️ Mini-Lineage Remastered

**Mini-Lineage Remastered** is a modern rewrite of the classic text-based RPG. Built with Elixir,
Phoenix LiveView and OTP, it revitalizes the nostalgic gameplay loop with real-time state
synchronization, procedural 8-bit audio synthesis, and an aesthetic dark fantasy user interface.

## 🌟 Key Features
### 🎮 Gameplay & Combat
- **Distinct Racial Profiles**: Choose between **Humans**, **Orcs**, **Elves**, and **Dark Elves**, each with its own starting health, inheritance, innate critical chance, ambush risk, and passive HP regeneration — plus a fixed rival race you fight for the whole run.
- **Tactical Combat Simulation**: Dynamically scaled encounters where Weapon Attack drives enemy party size, XP and Adena payouts, while Armor Defense mitigates incoming damage *sub-linearly* so stacking armor never reaches invincibility.
- **Punchy Critical Strikes**: A `1.9×` critical multiplier applied to enemies slain, XP, and Adena alike, so a crit stays impactful at every attack tier.
- **Chain Ambush Engine**: Every fight rolls a fresh ambush against your live ambush risk. Two consecutive ambushes inflict the `Hexed` debuff (`+4% Ambush Risk`, `-2% Crit`, 1 minute), snowballing the danger for reckless adventurers.
- **Equipment & Progression**: 6 weapon tiers and 6 armor tiers, the top ones carrying innate modifiers (*Calamity Comet*'s crit, *Eternal Aegis*' regen), across a level curve that runs to **level 80**.
- **Playable Without a Mouse**: The main panel's first control takes focus on arrival, so <kbd>Space</kbd> on the Battleground fights again and again, and <kbd>↑</kbd><kbd>↓</kbd> + <kbd>Enter</kbd> drives travel and the shops. Focus is reclaimed after each request re-enables its button, never stolen from a control you moved to yourself, and never placed on the death screen — where a stray keypress would submit your score or restart your character.

### 🎧 Procedural 8-Bit Web Audio Engine
- **Zero Audio Assets**: 100% synthesized in real time via the browser's native `AudioContext`, `OscillatorNode`, and `GainNode`.
- **Event-Driven Soundscapes**: Seven declaratively-defined voices — Game Start, Critical Hit, Ambush Alarm, Level Up Fanfare, Inn Dining, Shop Purchase, and Death.
- **Gesture-Safe Unlock**: A single capture-phase pointer/keyboard listener resumes the `AudioContext` on the very first user interaction — sounds fire from socket-ack handlers, not DOM markers, so nothing ever races a reload.
- **Client Mute Controls**: Persistent audio toggle stored in `localStorage` with non-blocking UI controls.

### ⚡ Real-Time Engine & Zones
- **Server-Side Tick Cadence**: A 5-second tick loop applies passive HP regeneration and sweeps expired buffs/debuffs, alongside exact per-effect timers so an expiry fires to the millisecond rather than waiting for the next tick.
- **Location-Based Zones**: The client reports its current screen (`player:screen`); the server classifies that as a combat zone (Battleground, Suicide, Death — regeneration pauses) or a resting zone (Town, Inn, Shops, Character, Highscores — regeneration applies). Being *ambushed* forces combat regardless of what the client claims, so a raw socket client can never lie its way out of one.
- **Disengaging Takes Five Seconds**: Leaving a combat zone does not rest you instantly — ⚔️ *In Combat* stays, gains a 5-second countdown, and only when that elapses does 💤 *Resting* take over and regeneration resume. Standing in a combat zone keeps you flagged *indefinitely* with no countdown at all, so waiting on the Battleground never restores a single point of health. The countdown is anchored to leaving the zone, so stepping back in cancels it and stepping out again starts a fresh one.
- **Regeneration Is Earned, Not Assumed**: 🌿 *Regenerating* is derived per snapshot rather than stored, so it appears and vanishes on its own: it needs the resting aura, a wound, and a positive HP-regen rate at once. An Orc (no innate regen) never sees it; a player at full health loses it the instant they top up.
- **Non-Mutating Reads**: Connecting, reconnecting, or refreshing only ever *reads* state. A fight happens exclusively on an explicit `battle:fight` — never on page load — which makes the classic navigate-away-mid-ambush exploit structurally impossible instead of merely punished.
- **LiveView Streaming**: One WebSocket carries the whole game. Every action is a `phx-click` or `phx-submit`; the server diffs the rendered HTML and pushes only what changed — HP and status on tick, effect expiry to the millisecond, and every player action, with no page reloads. Multiple tabs on one session stay in sync over `Phoenix.PubSub`.

### 🍖 Inn & Consumables
- **Tiered Meals**: Five dishes from *Spiced Ale* to *Roasted Pheasant*. All restore HP; the top three also grant a timed buff (*Satisfied*, *Well Fed*, *Gourmet Feast*) that temporarily expands the maximum health pool. Only one food buff is active at a time — a new meal replaces the old one.

### 🏆 Leaderboards & Statistics
- **Live Leaderboards**: The top 25 adventurers ordered by total Experience, then Adena — filterable per race. Cowards and cheaters are barred from posting.
### 🛡️ Security & Reliability
- **One Place For Every Access Rule**: `Access.pin_screen/2` decides where a player is allowed to be, and every navigation funnels through `handle_params/3` — an in-app link, a typed URL and the Back button all obey the same checks. The dead are confined to the death screen; the living are kept *off* it (it offers "Play Again?", which wipes the character); a player with a character cannot wander back into character creation, Statistics or Races; a visitor without one is confined to Game Start, Statistics, Races and Highscores; and an ambushed player is pinned to the battleground. The game owns every URL — an unrecognised path resolves to Town rather than erroring.
- **Guarded Mutations**: Every event that changes state declares its own preconditions, enforced server-side. Client-side routing is convenience; these guards are the boundary. Notably restarting requires a *dead* character, so a living one can never be wiped.
- **A Process Per Character, Not A Lock**: Each character is a `GenServer` under a `DynamicSupervisor`, addressed through a `Registry`. Serialisation is a property of the mailbox rather than a mutex a caller must remember to take, so concurrent actions on one session cannot interleave into a lost update.
- **Revision-Guarded State**: Every persisted mutation bumps a monotonic `revision`, so a stale push can never clobber fresher state.
- **Security Hardening**: A CSP with no inline scripts, `httpOnly`/`sameSite` session cookies, validation on every payload, and sliding-window rate limiting (60 battles and 30 shop actions per minute, plus a 300/min flood limiter). Rate limits are bypassed outside a release build so local development isn't throttled.
- **Idle Characters Are Reaped**: A character process arms a stop timer the moment it starts and cancels it when a viewer attaches, so a crawler or health check leaves nothing running. Rows outlive the process and are swept after 30 days — the same window the session cookie uses.

## 🛠️ Tech Stack

- **Runtime**: Elixir 1.19 on OTP 28, served by Bandit
- **Web**: Phoenix 1.8 with LiveView 1.1 — server-rendered HTML over one WebSocket, no client-side framework and no client-side router
- **Concurrency**: One `GenServer` per character under a `DynamicSupervisor` + `Registry`; `Phoenix.PubSub` for multi-tab sync; `Process.send_after/3` for the 5-second tick and for exact per-effect expiry
- **Database**: Ecto + MyXQL against MariaDB, with each character persisted as a single JSON document
- **Audio Engine**: Web Audio API (procedural synthesizer), driven from a LiveView JS hook
- **Testing**: ExUnit, plus a Playwright walkthrough that drives a real headless Chromium

Requires **Elixir 1.19+ on OTP 28+**, and a reachable MariaDB or MySQL.

## Running it

The Erlang and Elixir toolchain lives outside this repo (there is no root on this machine, so it
was installed from precompiled builds into `~/.local/lib`). One line puts it on your `PATH`:

```bash
cd ~/mini-lineage-remastered
source .elixir-env          # needed once per terminal
mix setup                   # first time only: deps, database, assets
mix phx.server
```

Then open **http://localhost:4000**.

To keep an IEx shell attached while it runs — handy for poking at a live character:

```bash
iex -S mix phx.server
```

If you would rather not source anything, add this line to `~/.bashrc`:

```bash
source ~/mini-lineage-remastered/.elixir-env
```

## Which database

| what | database | from | port |
|---|---|---|---|
| `mix phx.server` | your real characters, highscores and statistics | `DB_DATABASE` | `PORT` (4000) |
| `mix test` | a throwaway one | `DB_DATABASE_TEST` | — |
| `e2e/serve.sh` | the same throwaway one | `DB_DATABASE_TEST` | `PORT_E2E` (4002) |

Settings come from the repo-root `.env` — see [.env.example](.env.example) for what each one does.
A real environment variable always beats the file, which is how `e2e/serve.sh` and CI override it.
`config/runtime.exs` reads it at BOOT, so a release started with `bin/mini_lineage start` picks up
the same file rather than needing every variable on the command line; it looks in the working
directory, and `ENV_FILE` names it elsewhere.

Both servers can run at once — the walkthrough has its own port and its own database precisely so
it can create characters, spend adena and submit highscores without touching real data.

## Commands

```bash
mix phx.server        # run the game            (:4000, real dev data)
mix test              # the Elixir suite
mix ecto.migrate      # apply pending migrations
mix ecto.migrations   # what is applied
mix format            # format
mix compile --warnings-as-errors
mix balance           # the balance simulations — see below
```

## Balance simulations

The ten studies that tuned this game, carried over from the TypeScript implementation this
replaced. They read the shipped constants, so a rebalance is re-measured by rerunning them rather
than by editing them.

```bash
mix balance                 # list them
mix balance crit_balance    # run one
mix balance all             # run every one
```

They compile only in `:dev`, so no release carries them.

## Building a release

`config/runtime.exs` is read at boot, not at build, so nothing here needs a database or a secret
until the release actually starts.

```bash
MIX_ENV=prod mix deps.get --only prod
MIX_ENV=prod mix assets.deploy      # esbuild --minify, then phx.digest
MIX_ENV=prod mix release
```

Per command rather than `export MIX_ENV=prod`: an exported one outlives the build and follows you
into `mix test`, which then runs without the sandbox and fails complaining about the pool.

Then run it. `config/runtime.exs` reads `.env` at boot, so the release needs nothing on the command
line that the file already answers — from the repo root, this is the whole of it:

```bash
_build/prod/rel/mini_lineage/bin/mini_lineage eval 'MiniLineage.Release.migrate()'
PHX_SERVER=true _build/prod/rel/mini_lineage/bin/mini_lineage start
```

The file is looked for in the **working directory**, since a release has no repo checkout; `ENV_FILE`
names it anywhere else. A real environment variable always beats the file, so a platform that
injects its own `PORT` still wins.

The build stamps itself with `git rev-parse --short=7 HEAD`, which is what makes it a *release*
rather than a debug build: the footer links the commit, and — the part that matters — the error
screens stop naming the failure. Pass `APP_VERSION` to override it, and pass it explicitly wherever
the build has no git checkout to ask, which is every Docker build and every CI job. It must be the
short, seven-character form; a full sha does not count as a release.

A release carries no Mix, which is why migrations go through `MiniLineage.Release`. The database
may be named either by the discrete `DB_*` keys or by a single `DATABASE_URL`; the parts win when
both are set, because a URL cannot carry a password containing URL-unsafe characters unless they
are percent-encoded.

Production differs from development in ways worth knowing when something behaves oddly there:
rate limiting is **on** (60 battles and 30 shop actions per minute, 300 events/min overall),
`force_ssl` redirects to `https://$PHX_HOST` for every host except `localhost` and `127.0.0.1`,
the logger sits at `:info`, and there is no code reloader.

## Docker

`Dockerfile` builds the release on the same Elixir and OTP this is developed against, then ships
it on bare Alpine with no Elixir or Mix — the release brings its own ERTS. It provisions no
database of its own, so point `DB_HOST` at one the container can reach.

```bash
APP_VERSION=$(git rev-parse --short=7 HEAD) docker compose up --build
```

The container migrates before it serves, so a fresh database is never served against. Compose reads
`.env` itself and passes the values in as environment variables, so the image needs no copy of the
file — and those variables beat any file anyway.

## The browser walkthrough

Playwright drives a real headless Chromium through a whole playthrough — create a character,
travel, buy, fight, level up, die, submit a highscore, restart — and asserts that no request
failed, no console error was logged, a background tick disturbs neither the main panel nor an open
`<select>`, and the audio synth builds the graph it should.

Playwright is the only thing Node is still here for — two packages, and no build step:

```bash
npm ci
npx playwright install chromium
```

Then two terminals:

```bash
# terminal 1 — its own port and its own database, so it can play destructively
./e2e/serve.sh

# terminal 2 — the walkthrough
LD_LIBRARY_PATH=~/.local/lib/playwright-deps npm run test:e2e
```

`LD_LIBRARY_PATH` is required on this machine only: Chromium's `libnss3`/`libnspr4` were extracted
to `~/.local/lib/playwright-deps` rather than installed system-wide. With
`npx playwright install --with-deps chromium`, as CI does, it is not needed.

Each luck-dependent check reports the run that produced it — fights fought, meals eaten, level
reached — so a failure that only shows up once in a dozen runs still says what happened.

## What pins the balance

This game began as a TypeScript implementation, and the rewrite was held to it exactly. Two of
those instruments are permanent, and outlive the implementation they were built against:

- **`test/mini_lineage/game/balance_golden_test.exs`** — 400 fights across 4 races and 5 fixed
  seeds, pinned to exact numbers. Because every roll runs off one deterministic stream, it also
  pins the ORDER randomness is consumed in: adding, removing or reordering a draw anywhere in the
  fight path fails here even when each individual function is still correct.
- **`test/mini_lineage/game/js_parity_test.exs`** — `:math.pow`, the rounding of halves, and
  `toLocaleString('en-US')` number grouping, each pinned against values the original produced.

A deliberate balance or wording change means regenerating the affected expectations in the same
commit. **A diff in either file is exactly the change under review.**

## 📜 License

MIT — see [LICENSE](LICENSE). © 2026 Sunny
