# ⚔️ Mini-Lineage Remastered

**Mini-Lineage Remastered** is a modern rewrite of the classic text-based RPG. Built with Elixir,
Phoenix LiveView and OTP, it revitalizes the nostalgic gameplay loop with real-time state
synchronization, procedural 8-bit audio synthesis, and an aesthetic dark fantasy user interface.

## 🌟 Key Features
### 🎮 The Base Layer
- **Our Own Rules**: `docs/rules.md` is the whole player system, written by us with a worked example for every rule, and `rules_test.exs` holds the code to it. What comes next is in `docs/roadmap.md`.
- **Four Lineages, Two Paths**: **Humans**, **Orcs**, **Elves** and **Dark Elves**, each a **Fighter** or a **Mystic**: eight starting sets of six attributes (STR, CON, DEX, INT, WIT, MEN), and a fixed rival race fought all run. Every character starts at level 1 with no Adena.
- **Stats That Grow With You**: Max HP and MP rise a little more with every level, and P.Atk, M.Atk, P.Def, M.Def, Accuracy, Evasion, Critical and speed are all worked from the attributes and the level, up to **level 80**.
- **Old Mechanics, Kept For Their Pages**: The Inn, the Weapon and Armor Shops and the Battleground are what the game was before the base layer. They stay for their page design until items and fighting are rebuilt on the rules.
- **Playable Without a Mouse**: The panel's first control takes focus on arrival, so <kbd>Space</kbd> fights on the Battleground and <kbd>↑</kbd><kbd>↓</kbd> + <kbd>Enter</kbd> drives travel and the shops. Pressing a button hands focus to whatever answers — buying gives it back to the picker — while a control you moved to yourself is left alone. The death screen takes no focus and releases any it inherits, so the <kbd>Space</kbd> that fought cannot submit a score unread.

### 🎧 Procedural 8-Bit Web Audio Engine
- **Zero Audio Assets**: 100% synthesized in real time via the browser's native `AudioContext`, `OscillatorNode`, and `GainNode`.
- **Event-Driven Soundscapes**: Six declaratively-defined voices — Game Start, Critical Hit, Level Up Fanfare, Inn Dining, Shop Purchase, and Death.
- **Gesture-Safe Unlock**: A pair of capture-phase, fire-once `pointerdown`/`keydown` listeners resume the `AudioContext` on the very first user interaction — sounds fire from events the server pushes, not DOM markers, so nothing ever races a reload.
- **Client Mute Controls**: Persistent audio toggle stored in `localStorage` with non-blocking UI controls.

### ⚡ Real-Time Engine & Zones
- **Server-Side Tick Cadence**: A 3-second tick loop applies passive HP and MP regeneration and sweeps expired buffs/debuffs, alongside one expiry timer re-armed at the earliest effect deadline, so an expiry fires on time rather than waiting for the next tick.
- **Location-Based Zones**: The server classifies the reported screen as combat (Battleground, Death — regeneration pauses) or resting (everywhere else a living run can stand: Town, the Inn, the shops, the Character screen, the Halls, the Tome and the Chronicles of Ancestry). The error page is never recorded as a place, so it keeps whatever aura the run arrived with.
- **Disengaging Takes Five Seconds**: Leaving combat keeps ⚔️ *In Combat* for a 5-second countdown before 💤 *Resting* resumes regeneration. Standing in a combat zone keeps the flag indefinitely, so waiting on the Battleground never heals; stepping back in cancels the countdown.
- **Regeneration Is Earned, Not Assumed**: 🌿 *Regenerating* is derived per snapshot rather than stored, so it appears and vanishes on its own: it needs the resting aura and an HP or MP bar short of full, and carries a rate for each; a player at full health and mana loses it the instant they top up.
- **Every Effect, Spelled Out**: The banner wears buffs, debuffs and auras as emoji, which a phone can neither hover nor read — so a run's own page gives each one a paragraph under *Blessings & Afflictions*: what it is, what it is doing, and its modifiers coloured the way every other figure on the page is. Nothing is fetched for it, the view already carries them, and paragraphs appear and go on their own as effects are applied and lapse — the character's own expiry timer sees to the timing, so a buff leaves the page the second it ends rather than at the next tick, and the heading goes with the last of them. Told in the reader's voice: your own record speaks to you, somebody else's speaks about them.
- **Non-Mutating Reads**: Connecting, reconnecting and refreshing only *read* state. A fight happens only on an explicit `fight` event, never on page load.
- **LiveView Diffs**: One WebSocket carries the whole game. The server diffs the rendered HTML and pushes only what changed, with no page reloads. Multiple tabs on one session stay in sync over `Phoenix.PubSub`.

### 🍖 Inn & Consumables
- **Tiered Meals**: Five dishes from *Spiced Ale* to *Roasted Pheasant*. All restore HP; the top three also grant a timed buff (*Satisfied*, *Well Fed*, *Gourmet Feast*) that temporarily expands the maximum health pool. Only one food buff is active at a time — a new meal replaces the old one.

### 🏆 Leaderboards & Statistics
- **Live Leaderboards**: The top 25 adventurers ordered by total Experience, then Adena — filterable per race. Cheaters are barred from posting.
- **The Tome of Lore**: Every lifetime counter the realm keeps, told as its own history rather than as a table — souls set forth, levels climbed, foes felled, blood shed, fortunes made and spent. Live too, so the archives move under you as other people play.
- **Figures Count, They Don't Jump**: Every number you can watch change counts up to it — experience, purses, tallies, levels, what a weapon grants. A purse counts in its own short form, so `1.5k` climbs to `1.6k` rather than through six digits. Only names and dates jump, having nothing to count through.
### 🛡️ Security & Reliability
- **The Fallen May Look Back**: Death keeps everything but health and effects, so a dead character can still open its own Character screen — keeping its ancestry's emoji, closing on ☠️ *Journey Has Ended* and written in the past, closing on how the road ran out — voiced for whoever is reading, so a stranger's record never addresses them as *you*. A fallen run carries one thing, 👻 *Ghost*, derived from being dead rather than held: `kill/1` empties the effect list, so nothing a run had survives it, and the ghost folds in no modifier of its own. A run nobody holds the session of carries not even that, there being nothing walking with a run that has been walked away from. The section itself is drawn on one condition, that there is something to draw: no effect, no heading, whoever the run belongs to and whatever became of it. The dead may also reach the Halls, where their run already stands.
- **One Place For Every Access Rule**: `Access.pin_screen/2` decides where a player may be, and every navigation funnels through `handle_params/3`, so an in-app link, a typed URL and the Back button obey the same checks. **The pin is about what you may DO, not what you may read.** Five screens carry no action at all — a record, the Halls, the Tome, the Chronicles of Ancestry and the error page; the Halls' sort buttons reorder the view and the Chronicle pages itself, but nothing on them touches the run — so every state may read every one of them. What is gated is the rest: the dead are confined to their own ending and the living kept off it, and a player with a character cannot re-enter character creation. What the game does **not** do is move you for a path it has never had: an unrecognised URL is a **404** in the game's own shell, address left alone, exactly as a record for a character who does not exist already says so at its own URL. Redirecting one to Town would be a soft 404 — the reader learns nothing, the address they typed is thrown away, and a mistyped stylesheet comes back as HTML that the browser then fails to parse.
- **The URL Is Where You Are**: Game Start, Home Town and Game Over are one run's three states and all live at `/`, told apart by the character rather than by the address — you never travel to your own death. Somewhere you can stand keeps a URL of its own: the Battleground, the shops, the Character screen.
- **Guarded Mutations**: Every event that changes state declares its own preconditions, enforced server-side. Client-side routing is convenience; these guards are the boundary. Notably restarting requires a *dead* character, so a living one can never be wiped.
- **A Process Per Character, Not A Lock**: Each character is a `GenServer` under a `DynamicSupervisor`, addressed through a `Registry`. The mailbox serialises, so concurrent actions on one session cannot interleave into a lost update.
- **Versioned Documents**: Each character's state records the shape it was written in, so a later reshape has something to branch on, and a document from a newer build is refused rather than read with every unrecognised field defaulted away.
- **Writes Follow the Player, Not the Clock**: A character lives in its process, so the database is durability rather than storage. What the player *did* — a fight, a purchase, a death — is written before they are told it worked, and so is anything that earns a line in the chronicle, a buff wearing off included: somebody may be reading that log live. The rest of the passage of time — passive regeneration, which screen they wandered to — rides along with the next write, or with the process stopping. A hard kill costs a little healing and nothing else.
- **The Whole Run Is Kept**: Every deed appends a row to `character_log`: what kind of deed it was, the lines it was told in, and when. The totals the Tome tells are running counters of their own, so the log keeps only what a reader reads. It is the one thing allowed to grow without limit, since an append never rewrites what came before, where the character's own document is rewritten whole on every save. An entry belongs to its run for good, and any run's chronicle can be read from its own page — in a panel of its own beside the record, growing to the record's height and no further (stacked on a phone, it folds away until asked for) — a log that opens on the last thing the run ever did and follows new ones down, so a page is the same height whether a run fought nine times or nine hundred. It is **not only the fights**, and each deed is told in the very sentence its owner's alert said, so the two cannot disagree: who the run set out as, what it paid for everything it bought, the lineage it chose, the blades it took up, the meals it ate, the levels it reached, what settled over it and what left — whether a timer ended it, another meal replaced it, or it faded with the run's last breath, the losses just before the ending and in the order they arrived — the heresy if it committed one, and how it ended. However a run ends, its last entry is an *Ending*. Auras are left out on purpose — ⚔️ and 💤 flip on nearly every action, and logging them would drown everything else. Each entry is headed by the instant it happened and what kind of thing it was — *Beginning*, *Battle*, *Purchase*, *Level Up*, *Buff*, *Debuff*, *Cheat*, and *Ending* for every ending however it came — and a beginning, a purchase and a level reached are each washed in the colour of the alert that would announce them. The instant is rendered on the reader's own clock under **one** hook for the whole list rather than one per row, and the page opens on the **newest 25**, fetching the page before by keyset as the reader nears it. A reader at the newest entry holds one height, the oldest letting go as each new one lands; one scrolled back keeps everything they have; a refresh comes back to 25. A fatal fight is the exception, and deliberately: `resolve_battle_outcome/2` returns the moment health reaches zero, *before* the XP, the Adena, the battle count **and the kill count** are credited — so nothing the fighter did in it counted. The lines naming a reward described one never given; the line naming the foes cut down described foes the game never recorded as dead, when it was the fighter who died. Every line is drawn all the same, so the dice land identically, and then none of them is kept, in the log or in memory, for the one thing that is true: **how it ended**, logged as the run's *Ending* and wearing the same red the death screen wears. The record's own prose tallies the run and leaves the ending to the chronicle, rather than both saying it two paragraphs apart. And every entry is told to whoever is reading it: a stored line keeps its pronouns open, so the run's own battle screen says "you cut down four Humans" and a stranger reading the same row on the same record says "they cut down four Humans" — one row, no second copy of the sentence. A fight's entry is the whole of it, told the way it was told when it happened: the critical strike, the blow that landed, what the armour turned aside and what it was worth, how the fighter walked away. Only the line that was a button label is left out, having been an invitation rather than a record.
- **Security Hardening**: A CSP with no inline scripts, `httpOnly`/`sameSite` session cookies (and `Secure`, behind HSTS, in production), validation on every payload, and sliding-window rate limiting (60 battles and 30 shop actions per minute). Rate limiting is on in production and off everywhere else, so local development isn't throttled; `RATE_LIMIT` overrides it either way.
- **A Live Hall of Champions**: The board is a view of the characters rather than a table of its own, so a run appears the moment it chooses a race and keeps its place when it ends — nobody is asked to write themselves in. It refreshes for everyone reading the Halls as people play, coalesced into one recomputation per window rather than one query per viewer, and only when something on it moved, and any row opens that run's full record at `/character/:id` — the same page your own sidebar link opens, told in the third person because it is somebody else's, and **live while you read it**: sit on a rival's record and watch their gear, their tallies and their chronicle move as they play. The Konami cheat disqualifies a run: it keeps its record and its own page, but the Halls will not list it — and from that moment its **deeds** stop writing the realm's history, so a cheat's ×4 winnings never reach the Tome of Lore. The **census** still counts it: everyone who sets foot is counted and so is everyone who falls, because the Tome tells the Heretics as a few *of* the fallen, and a part cannot outnumber its whole.
- **The Board Reads At A Glance**: The first three overall wear 🥇🥈🥉, and they mean the same everywhere — filter to one lineage and its leader goes bare unless they are top three of *everyone*. A run has three ends: **fallen**, **going**, or **missing**. Going tints its row green; your own tints gold and wins where both apply; a green `•` beside the name means somebody is online with that character **right now** — read from the process registry, so it costs no query. Missing is the quiet one: a run abandoned past the retirement window keeps its record but loses its session, so it can never be picked up again and reads as plainly over, without pretending it died. A run is dated by **its last entry in the chronicle**, read from the log rather than stored beside it, so the Halls, the road on the run's own page and the bottom of its chronicle cannot disagree — they were two copies of one fact once, and drifted. A buff wearing off is an entry, so it dates the run; a regenerating tick and a closing tab write the row and log nothing, so they do not. The date costs one `LIMIT 1` walk down an index the log already had, and the whole board — every lineage and the date of every row — is **one statement**: measured on a million-entry log, a refresh went from 3.6ms to 2.3ms. Times are stored as instants and rendered on the reader's own clock.
- **Two Identities Per Character**: A character's `id` is public and appears in every board link; the `session_id` in the cookie is secret and is what actually plays it. Keeping them apart is what stops a champion's URL being a working login for that character. Starting over retires the run and takes a new character, but keeps the session — it names the browser, not the run.
- **Nothing Is Reaped, Only Retired**: A character process arms a stop timer at start and cancels it when a viewer attaches, so a crawler leaves nothing running. A run that leaves with a timed buff or debuff still on it is the exception: its process stays up until it lapses, at most five minutes, so the lapse is logged when it happens and dated then, rather than whenever the player comes back — and heals nobody while it waits, since an absent player does not regenerate. After 30 days — the window the session cookie uses — an untouched run gives up its session and stays in the Halls. No row is ever deleted: a visitor who never chose a lineage is held in memory and never written at all.

## 🛠️ Tech Stack

- **Runtime**: Elixir 1.20 on OTP 29, served by Bandit
- **Web**: Phoenix 1.8 with LiveView 1.2 — server-rendered HTML over one WebSocket, no client-side framework and no client-side router
- **Concurrency**: One `GenServer` per character under a `DynamicSupervisor` + `Registry`; `Phoenix.PubSub` for multi-tab sync; `Process.send_after/3` for the 3-second tick and for effect expiry
- **Database**: Ecto + Postgrex against PostgreSQL 18, with each character persisted as a single `jsonb` document
- **Audio Engine**: Web Audio API (procedural synthesizer), driven by events the server pushes over the socket
- **Testing**: ExUnit with StreamData properties, plus four Playwright suites that drive a real headless Chromium
- **Dev tools**: LiveDebugger, Tidewave (MCP for coding agents) and Benchee, all `:dev` only and none of them in a release

Requires **Elixir 1.20 on OTP 29** (what CI and the image pin), and a reachable **PostgreSQL 12+** — the floor is `STORED`
generated columns, which is what the board ranks on. Development runs 18.6 and CI the current 18; below that,
prefer whatever upstream still supports over the bare minimum.

## Running it

Once, ever:

Elixir and OTP as above, and Node at the version `.nvmrc` pins, which runs Playwright and nothing
else: `nvm install` in the repo picks it up, and `mix e2e` refuses any other. The browser suites also
call `curl`, `ss`, `ps` and `pkill`.

```bash
grep -q 'mini-lineage-remastered/env.sh' ~/.bashrc \
  || echo '[ -f ~/mini-lineage-remastered/env.sh ] && source ~/mini-lineage-remastered/env.sh' >> ~/.bashrc
exec bash                   # or just open a new terminal

cd ~/mini-lineage-remastered
cp .env.example .env        # then fill in the database it names
cp .env.test.example .env.test
mix setup                   # deps, database, assets, and the test browser
mix test                    # also creates the throwaway database the browser suites share
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

`mix setup` runs `npm ci` and installs Chromium for you (`mix e2e.setup` alone). The npm scripts
forward to mix — `test:e2e` to `mix e2e walkthrough`, `test:e2e:races` to `mix e2e races`,
`test:e2e:all` to `mix e2e` — so there is one way in, not two.

## Which database

| what | database | reads | port |
|---|---|---|---|
| `mix phx.server` | your real characters, board and statistics | `.env` | `PORT` (4000) |
| `mix test` | a throwaway one | `.env.test` | — |
| `mix e2e` | the same throwaway one, board emptied first | `.env.test` | `PORT` (4002) |

Two files, the same key names in each: `config/runtime.exs` picks `.env.test` whenever `MIX_ENV`
is `test` or `e2e`, so nothing has to remember a flag, and the throwaway database can live on
another host entirely rather than merely under another name.

An unreleased build names itself in the footer — `🔥development` on 4000, `🍃testing` on 4002 —
so the two are never confused. A release names its commit instead.

`mix dev` and `mix prod` read the same `.env`, so they play the same characters — and, because the
cookie is only legible to the secret that signed it, the same `SECRET_KEY_BASE`. Switching between
them keeps you signed in as whoever you were. Rotating that secret signs everyone out at once;
their characters are untouched, but no browser can prove which one is its own.

Three tables. `characters` keeps each run's state as one `jsonb` document, alongside generated
columns Postgres derives from it — name, race, experience, wealth, dead, disqualified — so the
board sorts relationally and cannot drift from the document. `character_log` is a row per deed,
pointing at the character that did it. `statistics` is the lifetime counters.

There is no highscores table: the Halls are a query over `characters`.

See [.env.example](.env.example) and [.env.test.example](.env.test.example) for what each setting
does. A real environment variable always beats the file, which is how CI supplies them without
either file present.

`config/runtime.exs` reads the file at BOOT, so a release started with `bin/mini_lineage start`
picks it up from its working directory; `ENV_FILE` names it elsewhere.

Both servers can run at once: the browser suites have their own port and their own database, so
they can create characters, spend adena and fill the board without touching real data. They empty
that board before each run through `e2e/reset.sh`, which refuses to touch whichever database
`.env` names — so the throwaway one can be called anything, on any server.

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
mix e2e                 # every browser suite — see below
mix e2e walkthrough     # ...one character, played normally
mix e2e races           # ...every lineage
mix e2e live-board      # ...two players at once, watching the board move
mix e2e log             # ...the log hook, in both orders it reads

mix ecto.migrate        # apply pending migrations
mix ecto.migrations     # what is applied
mix ecto.reset          # drop everything and rebuild it (destructive)

mix format
mix compile --warnings-as-errors
mix precommit           # compile --warnings-as-errors, deps.unlock, format, test
MIX_BUILD_PATH=_build/bench mix run --no-start bench/board.exs   # the board's timings — see below
```

`mix dev` does not migrate: that is a deployment step, and `mix start` does it. Run
`mix ecto.migrate` yourself after pulling a schema change.

**Ctrl-C does not stop the server `mix start` and `mix prod` launch** — Erlang puts it in its own
process group, beyond this terminal's interrupt. Use `mix stop`. If you forget, `mix dev` and
`mix start` say so by name rather than failing on `:eaddrinuse`.

`mix test.coverage` reports, it does not gate. The browser suites exercise the web layer and are
not instrumented, so the number understates what is covered.

## Development tools

All `:dev` only. None reaches a release, the test suite or the browser suites, and none changes
the page's Content Security Policy: dev serves the same one prod does.

**[LiveDebugger](https://github.com/software-mansion/live-debugger)** runs beside the game on
<http://localhost:4007> while `mix` is up: every LiveView process, its assigns, and a trace of each
`mount`, `handle_params`, `handle_event` and `handle_info` with how long it took. Its
[Chrome](https://chromewebstore.google.com/detail/gmdfnfcigbfkmghbjeelmbkbiglbmbpe) or
[Firefox](https://addons.mozilla.org/en-US/firefox/addon/livedebugger-devtools/) extension opens the
same thing as a DevTools tab on the game page. Its in-page features are off, so it injects no script:
there is no debug button over the page and no click-to-inspect, and nothing else is missing. Its
assigns view shows the session id, which signs in as that character, so keep screenshots of it to
yourself.

**[Tidewave](https://github.com/tidewave-ai/tidewave_phoenix)** gives a coding agent the running
app over MCP: Elixir evaluated inside it, SQL against the dev database, its logs, and docs for the
exact dependency versions locked here. `.mcp.json` points Claude Code at
`http://localhost:4000/tidewave/mcp`, so start `mix` first, then approve the server once. It is
plugged in on `/tidewave/*` only, because on any other response it would loosen the CSP.

**[Benchee](https://github.com/bencheeorg/benchee)** scripts live in `bench/` and time the code
path that ships, through Ecto, against the dev database:

```bash
MIX_BUILD_PATH=_build/bench mix run --no-start bench/board.exs
BENCH_TAG=before MIX_BUILD_PATH=_build/bench mix run --no-start bench/board.exs  # then change, and run again
```

Each run is saved under the branch, or `BENCH_TAG`, in `tmp/bench/`, and every other saved run is
printed beside it. The separate build path is what lets it run while `mix` is serving: both
compiling into `_build/dev` at once corrupts the beams the server is loading.

**[StreamData](https://github.com/whatyouhide/stream_data)** is `:test` only, and runs with
`mix test`. Its properties sit beside the fixed tables: the formatters for any number, a table's
sort for any rows, and a fight for any roll of the dice. They generate the rolls and feed them
through the game's own RNG, so a rule like "a fatal fight pays nothing" is checked for every fight
rather than for one seed's.

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
MIX_ENV=prod mix assets.deploy      # esbuild --minify, then phx.digest
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

If a migration has to come back out, the same binary rolls it back, given its version — the
timestamp its file in `priv/repo/migrations` starts with:

```bash
bin/mini_lineage eval 'MiniLineage.Release.rollback(MiniLineage.Repo, <version>)'
```

That undoes the named migration and every one after it. The initial migration is the whole schema,
so naming it, or `0`, drops every table.

The build stamps itself with `git rev-parse --short=7 HEAD` and the footer links that commit.
`APP_VERSION` overrides it, in the seven-character form, and is required wherever the build has no
checkout to ask — a Docker build, or CI. A release that can supply neither refuses to assemble.

A release carries no Mix, so migrations go through `MiniLineage.Release`. Name the database with
the `DB_*` keys or with a single `DATABASE_URL`; a set `DB_DATABASE` wins when both are. The image ships
the migrations it was built with, so a stale one reports "Migrations already up" and means it —
rebuild before believing that.

Production differs from development: rate limiting is **on** (60 battles and 30 shop actions per
minute), `force_ssl` redirects every plain-http request to `https://` on the host it
was asked for, `localhost` and `127.0.0.1` excepted, the logger sits at `:info`, and there is no code reloader.

`RATE_LIMIT` overrides the first and `LOG_LEVEL` the logger per deployment, with no rebuild — both are read
at boot rather than baked. `RATE_LIMIT` throttles only for `true` or `1`, so any other value turns it
off; a `LOG_LEVEL` that is not a Logger level stops the boot. Most other tuning is not: anything reached through `compile_env`, the
character TTL among it, is fixed when the image is built and a release refuses to start if the
environment disagrees with what it was built with.

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

docker run --rm --init -p 4000:4000 --env-file .env \
  --add-host host.docker.internal:host-gateway \
  -e DB_HOST=host.docker.internal \
  mini-lineage
```

Three things decide whether that works:

- **`DB_HOST` must be reachable from inside the container.** `127.0.0.1` there is the container
  itself, not your machine — hence the `--add-host`/`-e` pair above. A database on another host
  needs neither.
- **`--env-file` is Docker's own parser, not this app's.** It keeps a comment written after a
  value, so `PHX_HOST=localhost # the domain` sets the hostname to the whole line — keep every
  comment on its own line. To use this app's parser instead, mount the file where the release
  reads it from: `-v "$PWD/.env:/app/.env:ro"`. The container runs as a non-root user, so that
  file must be readable by others.
- **Keep `PHX_HOST=localhost` for a local run.** With a real domain, `force_ssl` answers every
  plain-http request with a redirect to it; `localhost` and `127.0.0.1` are the excluded pair.

The build **requires** `APP_VERSION` — an image that cannot name its commit does not get built.
For a throwaway one, any seven characters will do.

### Checking a release the way a deployment runs it

```bash
e2e/release.sh
```

Builds the image as CI does, then does what a deployment does with it: reads the commit stamp back
out, starts the real `docker-compose.yml` against an empty Postgres 18, waits for its healthcheck
and the boot migration, checks that the socket takes `PHX_HOST`'s origin and refuses another, and
plays one turn in Chromium (`e2e/release.mjs`). It cleans up after itself, pass or fail. CI's
publish job runs the same script on the image it is about to push, so a green local run is that
run. `IMAGE` and `APP_VERSION` check an image already built instead; `RELEASE_PORT` moves it off
4100.

### Getting Docker without root

The rootless Engine needs no `sudo`, only `newuidmap` and a subuid range, which Ubuntu has:

```bash
curl -fsSL https://get.docker.com/rootless -o rootless.sh   # read it, then:
sh rootless.sh                    # ~/bin, a user systemd service, and a `rootless` context
```

It ships without buildx and compose, which CI uses; put both release binaries from
github.com/docker/buildx and github.com/docker/compose in `~/.docker/cli-plugins/` as
`docker-buildx` and `docker-compose`, checked against their published checksums. `~/.profile` puts
`~/bin` on the PATH from the next login shell. `podman build` also works, rootless, but the release
check wants Docker's buildx and compose.

### Deploying

CI publishes the image, so a server pulls rather than builds:

    ghcr.io/sunny-azu-red/mini-lineage-remastered:latest

The `publish` job runs only from `main` and only behind both green jobs, so what is deployed is
the artifact that passed. Before pushing it runs `e2e/release.sh` on the image, so nothing
reaches `latest` that did not boot, migrate and play a turn. Every
image is tagged twice, `latest` and its seven-character commit, so `IMAGE_TAG` pins or rolls back
to any of them; unset, it follows `main`.

The image is built for **amd64 only**. On an ARM host the pull fails; adding `platforms:` to the
publish job's build step is where that changes.

Two things to do once, on the package's page in GitHub: make it **public**, or Portainer will need a
registry credential to pull it; and, if you want, link it to the repository. Then point the stack at
this compose file and redeploy with **Re-pull image** on.

The footer names the commit the running build came from, which is how you tell a deploy took: it
links the commit, or names the unreleased build it is. There is no third answer.

CI supplies it as `APP_VERSION`. A build from a checkout finds its own, which is why the
Dockerfile takes a build arg rather than reading a `.git` a Portainer stack does not send.

**Put TLS in front of it.** `force_ssl` 301s every plain-http request to `https://` on the host it
was asked for: right behind a proxy that terminates TLS and sets `X-Forwarded-Proto`, a redirect
loop if exposed directly on port 80. `localhost` and `127.0.0.1` are excluded, which is how the
compose healthcheck reaches `/health`, which the endpoint answers before any session is minted.

**`PHX_HOST` is required, and it is not only about links.** `check_origin` is left at its default,
so the LiveView socket refuses every origin that is not this host. Name it wrongly and the page
loads, renders once and never connects again, with nothing in the log to say why; leave it unset
and the release refuses to boot rather than pretending to be `example.com`.

**What a deployment must set**: `PHX_HOST`; `SECRET_KEY_BASE`, at least 64 bytes, from
`mix phx.gen.secret`; and the database, as `DB_DATABASE` or a single `DATABASE_URL`. A bare release
refuses to boot without those three. `DB_HOST` (127.0.0.1), `DB_PORT` (5432), `DB_USERNAME`
(`postgres`) and `DB_PASSWORD` (empty) are defaulted. Compose also refuses to start without
`DB_HOST`, since its default would be the container itself. `PORT` (4000), `LOG_LEVEL` and
`RATE_LIMIT` are optional. `DATABASE_URL`, `POOL_SIZE` (10), `ECTO_IPV6` and `APP_VERSION` are read
by a bare release, but compose does not forward them; `APP_VERSION` set at boot overrides the
commit the footer names.

The image sets `LANG=C.UTF-8` (the VM otherwise runs latin1, and this game is made of emoji) and
carries `ca-certificates` for a database reached over TLS. Compose adds `init: true`, and the
standalone run `--init`, since the release runs as PID 1 and does not reap what the ERTS spawns.

## The browser suites

Four Playwright runs drive a real headless Chromium, sharing their controls through
`e2e/helpers.mjs`. A fifth, `e2e/release.mjs`, plays one turn against a built image and runs only
under `e2e/release.sh`:

- **`e2e/walkthrough.mjs`** — one character played normally, end to end: create, travel, buy,
  fight, die, read its own record, start over. It asserts that no request failed, no console error was
  logged, a background tick disturbs neither the main panel nor an open `<select>`, focus lands
  where the keyboard needs it, and the audio synth builds the graph it should.
- **`e2e/races.mjs`** — every lineage played through: each one's class, health and stats as the
  screens show them, what it can afford at birth, and its road to the board. With all four in the
  Halls it can check something one race cannot — that every filter narrows to rows of that race
  alone.
- **`e2e/live-board.mjs`** — two browser contexts at once, so two session cookies and two players.
  It watches one player's Halls change because of what the *other* one did, follows the link to a
  stranger's record, and checks that reading it never adopts their character. The others drive
  a single browser, so a board that only refreshed for whoever caused the change would pass them.
- **`e2e/log.mjs`** — the `Log` behaviour of a panel, in both orders a log reads: newest first as
  the Chronicle does, and oldest first as a chat would. It mounts the real hook on a harness of its
  own and checks the unread line, the pill, and that a reader keeps their place across patches.

Before each suite the board is emptied through `e2e/reset.sh`, which refuses to touch whichever
database `.env` names. The suites read the server's address from `E2E_BASE_URL`, which `mix e2e`
sets.

One command, one terminal:

```bash
mix e2e                 # all four
mix e2e walkthrough     # just the first
```

It migrates and empties the board, starts the isolated server, empties the board again before each
suite, drives Chromium, and stops the server it started. The first of those is why: the board is cached in the
running server, so one started against what the last run left behind would serve those rows. A server already running on that port is reused, so `e2e/serve.sh` in another terminal works too
but only if it is newer than every source file, because nothing here recompiles a server it did not
start. An older one is refused by name rather than quietly tested against.

One run at a time: they share a database and each empties the board first, so a second `mix e2e`
refuses and names the one already going.

No suite asserts on a roll of the dice. What the RNG decides is pinned in
`test/mini_lineage/game/balance_golden_test.exs`, which can seed it.

## Working on it

[AGENTS.md](AGENTS.md) carries the conventions this codebase holds to — how the dice are kept out
of tests, what belongs in a document and what belongs in columns, which writes are immediate, and
what the URLs mean. It is written for whoever, or whatever, is editing the code.

## 📜 License

MIT — see [LICENSE](LICENSE). © 2026 Sunny
