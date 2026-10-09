# ⚔️ Mini-Lineage Remastered

**Mini-Lineage Remastered** is a modern rewrite of the classic text-based RPG. Built with Elixir,
Phoenix LiveView and OTP, it revitalizes the nostalgic gameplay loop with real-time state
synchronization and an aesthetic dark fantasy user interface.

It is cut back, for now, to its base layer: who a character is and the numbers that make them.
Everything the game was before that (the Inn and the shops, the Battleground, the Halls, the Tome,
a run's record and its Chronicle) is kept to be read in [`legacy/`](legacy/README.md), and comes
back one system at a time as [`docs/roadmap.md`](docs/roadmap.md) builds it on the rules.

## 🌟 Key Features
### 🎮 The Base Layer
- **Our Own Rules**: `docs/rules.md` is the whole player system, written by us with a worked example for every rule, and `rules_test.exs` holds the code to it. What comes next is in `docs/roadmap.md`.
- **Four Lineages, Two Paths**: **Humans**, **Orcs**, **Elves** and **Dark Elves**, each a **Fighter** or a **Mystic**: eight starting sets of six attributes (STR, CON, DEX, INT, WIT, MEN). Every character starts at level 1 with no Adena.
- **Each Race Starts at Home**: A Human wakes in 🏝️ Talking Island Village, an Orc in 🏕️ Orc Village, an Elf in 🌳 Elven Village and a Dark Elf in 🌑 Dark Elven Village, and rests among its own people.
- **Towns and Gatekeepers**: Every town has a 🌀 Gatekeeper who sends you along a route for Adena (rules §14). The four villages each link only to the 🏰 Town of Gludio, and the mainland goes on to Dion; Giran and Giran Harbor are listed and not open yet.
- **Day and Night**: From 22:00 to 06:00, Bucharest time, a 🌙 aura costs every character 3 Accuracy (rules §15).
- **Race Perks**: A Dark Elf's Shadow Sense wins those 3 back at night, and an Elf rests half again as fast in Elven Village, under the Mother Tree (rules §16). Each shows as an aura, and nothing acts unseen.
- **Stats That Grow With You**: Max HP and MP rise a little more with every level, and P.Atk, M.Atk, P.Def, M.Def, Accuracy, Evasion, Critical and speed are all worked from the attributes and the level, up to **level 80**, on L2's own EXP table: 68 EXP for level 2, 4.2 billion for 80.
- **The Status Sidebar**: Beside the town, drawn like L2's status window: your race and class, your name beside your level, your HP, MP and XP bars, and an Inventory that holds your Adena and nothing else yet.
- **The Character Page**: Your name in the sidebar opens `/character`: your ancestry, class, attributes and perk, your level, bars and purse, every buff and debuff on you with what it does, and your combat stats (P.Atk, M.Atk, P.Def, M.Def, Accuracy, Evasion, Critical, M. Critical, both speeds and regeneration).
- **Chronicles of Ancestry**: `/races` tells every lineage before you choose one: its backstory, the village it starts in, and both of its starting classes with their attributes and their HP and MP at level 1.
- **Figures Count, They Don't Jump**: Every number you can watch change counts up to it. A purse counts in its own short form, so `1.5k` climbs to `1.6k` rather than through six digits. Only names and dates jump, having nothing to count through.
- **Two Sounds, Made On The Spot**: A heroic fanfare when a character is made and a chime when sound is switched back on, both 8-bit notes played by a Web Audio synth with no audio files. The 🔊 in the banner mutes them, and the browser remembers it.
- **Playable Without a Mouse**: The panel's first control takes focus on arrival, so the game plays from the keyboard, and a control you moved to yourself is left alone.

### ⚡ Real-Time Engine
- **Rest Heals, and Says So**: A character always rests (💤) for now, and wears 🌿 *Regenerating* while HP or MP is short of full. A 3-second tick restores both at the rates rules §11 gives, and the aura and the healing are one condition, so neither can appear without the other.
- **Non-Mutating Reads**: Connecting, reconnecting and refreshing only *read* state.
- **LiveView Diffs**: One WebSocket carries the whole game. The server diffs the rendered HTML and pushes only what changed, with no page reloads. Multiple tabs on one session stay in sync over `Phoenix.PubSub`.

### 🛡️ Security & Reliability
- **One Place For Every Access Rule**: `Access.pin_screen/2` decides where a player may be, and every navigation funnels through `handle_params/3`, so an in-app link, a typed URL and the Back button obey the same checks. It gates what may be *done*, not what may be read: the Chronicles of Ancestry and the error page are open to everyone, and a player with a character cannot re-enter character creation. Beside `/`, `/character`, `/races` and `/error`, every town and its Gatekeeper have a literal address built from the town table at compile time. An unrecognised URL is a **404** in the game's own shell, address left alone, rather than a redirect to town: that would be a soft 404, and a mistyped stylesheet would come back as HTML the browser then fails to parse.
- **The URL Is Where You Are**: A character stands in one town, and its address is that town's, `/orc-village` or `/gludio`. `/` is game start for a visitor and, for a character, the town it stands in.
- **Guarded Mutations**: Every event that changes state declares its own preconditions, enforced server-side. Client-side routing is convenience; these guards are the boundary.
- **A Process Per Character, Not A Lock**: Each character is a `GenServer` under a `DynamicSupervisor`, addressed through a `Registry`. The mailbox serialises, so concurrent actions on one session cannot interleave into a lost update.
- **Versioned Documents**: Each character's state records the shape it was written in, so a later reshape has something to branch on, and a document from a newer build is refused rather than read with every unrecognised field defaulted away.
- **Writes Follow the Player, Not the Clock**: A character lives in its process, so the database is durability rather than storage. What the player *did*, creating a character above all, is written before they are told it worked. Passive regeneration is buffered and rides along with the next write, a 60-second backstop, or the process stopping. A hard kill costs a little healing and nothing else.
- **Security Hardening**: A CSP with no inline scripts, `httpOnly`/`sameSite` session cookies (and `Secure`, behind HSTS, in production), and validation on every payload.
- **Two Identities Per Character**: A character's `id` is public; the `session_id` in the cookie is secret and is what actually plays it. Keeping them apart is what stops a public id being a working login for that character. The session names the browser, not the run.
- **Nothing Is Reaped, Only Retired**: A character process arms a stop timer at start and cancels it when a viewer attaches, so a crawler leaves nothing running. After 30 days (the window the session cookie uses) an untouched run gives up its session and its row stays. A visitor who never chose a lineage is held in memory and never written at all.
- **Debug-Build Shortcuts**: In dev and the e2e server, never in a release, keys typed outside a text field drive a few shortcuts. A release neither listens for them nor answers them, and a test checks each one both ways.

  | Type | What it does |
  |---|---|
  | `adena` | 10,000 Adena into the purse, every time |
  | `night` / `day` | holds the whole server at that hour until the other word or a restart |
  | `half` | HP and MP to half their maximum, and the XP bar halfway to the next level |
  | `lvl` | exactly the EXP the next level needs, which refills both bars |
  | `maxlvl` | exactly the EXP level 80 needs, which refills both bars |
  | Ctrl+Q | deletes the character, so one browser can try every race and path |

  A start form also comes with a name already written in. Any other key between two letters of a word breaks it. In Firefox on Linux, Ctrl+Q quits the browser before the page sees it.

## 🛠️ Tech Stack

- **Runtime**: Elixir 1.20 on OTP 29, served by Bandit
- **Web**: Phoenix 1.8 with LiveView 1.2 — server-rendered HTML over one WebSocket, no client-side framework and no client-side router
- **Concurrency**: One `GenServer` per character under a `DynamicSupervisor` + `Registry`; `Phoenix.PubSub` for multi-tab sync; `Process.send_after/3` for the 3-second tick
- **Database**: Ecto + Postgrex against PostgreSQL 18, with each character persisted as a single `jsonb` document
- **Client**: five LiveView hooks (`AnimatedValues`, `DevKeys`, `Panel`, `PanelFocus`, `SoundToggle`), a Web Audio synth, and no framework
- **Testing**: ExUnit with StreamData properties, plus two Playwright suites that drive a real headless Chromium
- **Dev tools**: LiveDebugger and Tidewave (MCP for coding agents), both `:dev` only and neither in a release

Requires **Elixir 1.20 on OTP 29** (what CI and the image pin), and a reachable **PostgreSQL**.
Development runs 18.6, and CI and the release check the current 18; prefer whatever upstream still
supports.

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
| `mix phx.server` | your real characters | `.env` | `PORT` (4000) |
| `mix test` | a throwaway one | `.env.test` | — |
| `mix e2e` | the same throwaway one, emptied first | `.env.test` | `PORT` (4002) |

Two files, the same key names in each: `config/runtime.exs` picks `.env.test` whenever `MIX_ENV`
is `test` or `e2e`, so nothing has to remember a flag, and the throwaway database can live on
another host entirely rather than merely under another name.

An unreleased build names itself in the footer — `🔥development` on 4000, `🍃testing` on 4002 —
so the two are never confused. A release names its commit instead.

`mix dev` and `mix prod` read the same `.env`, so they play the same characters — and, because the
cookie is only legible to the secret that signed it, the same `SECRET_KEY_BASE`. Switching between
them keeps you signed in as whoever you were. Rotating that secret signs everyone out at once;
their characters are untouched, but no browser can prove which one is its own.

One table. `characters` keeps each run's state as one `jsonb` document beside its public `id`,
its `session_id` and its timestamps, with a unique index on the session where there is one. A
retired run has none.

See [.env.example](.env.example) and [.env.test.example](.env.test.example) for what each setting
does. A real environment variable always beats the file, which is how CI supplies them without
either file present.

`config/runtime.exs` reads the file at BOOT, so a release started with `bin/mini_lineage start`
picks it up from its working directory; `ENV_FILE` names it elsewhere.

Both servers can run at once: the browser suites have their own port and their own database, so
they can create characters without touching real data. They empty it before each run through
`e2e/reset.sh`, which refuses to touch whichever database `.env` names — so the throwaway one can
be called anything, on any server.

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
mix e2e races           # ...every starting set

mix ecto.migrate        # apply pending migrations
mix ecto.migrations     # what is applied
mix ecto.reset          # drop everything and rebuild it (destructive)

mix format
mix compile --warnings-as-errors
mix precommit           # compile --warnings-as-errors, deps.unlock, format, test
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

**[StreamData](https://github.com/whatyouhide/stream_data)** is `:test` only, and runs with
`mix test`. Its properties sit beside the fixed tables: the short form Adena and XP are written in,
for any number, and the level table for any amount of experience.

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

Production differs from development: `force_ssl` redirects every plain-http request to `https://`
on the host it was asked for, `localhost` and `127.0.0.1` excepted, the logger sits at `:info`,
there is no code reloader, and the temporary Quit button is neither drawn nor answered.

`LOG_LEVEL` overrides the logger per deployment, with no rebuild — it is read at boot rather than
baked, and a value that is not a Logger level stops the boot. Most other tuning is not: anything
reached through `compile_env`, the character TTL among it, is fixed when the image is built and a
release refuses to start if the environment disagrees with what it was built with.

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
makes a character in Chromium (`e2e/release.mjs`). It cleans up after itself, pass or fail. CI's
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
reaches `latest` that did not boot, migrate and make a character. Every
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
`DB_HOST`, since its default would be the container itself. `PORT` (4000) and `LOG_LEVEL` are
optional. `DATABASE_URL`, `POOL_SIZE` (10), `ECTO_IPV6` and `APP_VERSION` are read
by a bare release, but compose does not forward them; `APP_VERSION` set at boot overrides the
commit the footer names.

The image sets `LANG=C.UTF-8` (the VM otherwise runs latin1, and this game is made of emoji) and
carries `ca-certificates` for a database reached over TLS. Compose adds `init: true`, and the
standalone run `--init`, since the release runs as PID 1 and does not reap what the ERTS spawns.

## The browser suites

Two Playwright runs drive a real headless Chromium, sharing their controls through
`e2e/helpers.mjs`. A third, `e2e/release.mjs`, makes a character against a built image and runs only
under `e2e/release.sh`:

- **`e2e/walkthrough.mjs`** — one character, made and stood in its village, end to end: the
  stylesheet and the CSP, the session cookie, a 404 and the error page, the Chronicles of Ancestry,
  creation from the keyboard, the new-game fanfare and the sound switch, the sidebar and the
  character page, the Inventory's fold on a phone, a second tab, the Gatekeeper's routes and fees,
  and every debug-build shortcut, Ctrl+Q last. It asserts that no request
  failed and no console error was logged, and that the browser shortens a figure exactly as the
  server does.
- **`e2e/races.mjs`** — every starting set born in a browser, which the walkthrough cannot do: it
  commits to one. Each lands in its own race's village with the numbers `docs/rules.md` gives it.

Before each suite the database is emptied through `e2e/reset.sh`, which refuses to touch whichever
database `.env` names. The suites read the server's address from `E2E_BASE_URL`, which `mix e2e`
sets.

One command, one terminal:

```bash
mix e2e                 # both
mix e2e walkthrough     # just the first
```

It migrates, starts the isolated server, empties the database before each suite, drives Chromium,
and stops the server it started. A server already running on that port is reused, so
`e2e/serve.sh` in another terminal works too, but only if it is newer than every source file,
because nothing here recompiles a server it did not start. An older one is refused by name rather
than quietly tested against.

One run at a time: they share a database and each empties it first, so a second `mix e2e` refuses
and names the one already going.

No suite asserts on a roll of the dice; a test that rolls pins them through `Rng.put_source/1`.

## Working on it

[AGENTS.md](AGENTS.md) carries the conventions this codebase holds to — how the dice are kept out
of tests, what belongs in a document and what belongs in columns, which writes are immediate, and
what the URLs mean. It is written for whoever, or whatever, is editing the code.

[docs/rules.md](docs/rules.md) is the base layer the game runs on, and
[docs/roadmap.md](docs/roadmap.md) what is built on it next. [legacy/](legacy/README.md) is the game
as it was before the cut, kept to be read and never run: start there when rebuilding a system it
had.

## 📜 License

MIT — see [LICENSE](LICENSE). © 2026 Sunny
