Mini-Lineage Remastered: a text-based RPG in Elixir, Phoenix LiveView and OTP. What is written here
beats any general Phoenix habit. How the game is drawn (type, layout, classes, colour) is in
[docs/design.md](docs/design.md): read it before touching a stylesheet, a class or a control's look.

## What exists

- **The live game is the base layer**: character creation, the towns of rules §14 with their
  Gatekeepers and the status sidebar, `/character`, the Chronicles of Ancestry at `/races`, and the
  error page. Everything the game was before that is in `legacy/` (see Rules).
- **Not here, so don't reach for it**: `core_components.ex` (no `<.icon>`, `<.input>` or
  `<.flash_group>`; every control is hand-written HEEx in `lib/mini_lineage_web/components/`); an
  HTTP client (no `Req` or `httpoison`; the zone database is `tz`, never `tzdata`, which brings
  hackney, and `tz`'s updater stays unused); authentication (a signed session cookie ties a browser
  to a character and nothing else); LiveView streams (one character's state is one assign);
  colocated hooks.
- **Hooks**: `app.js` imports them from `assets/js/hooks.js`, which holds nothing but that list. Each
  is its own file under `assets/js/hooks/`; a `ColocatedHook` would compile and never run. They are
  `AnimatedValues`, `DevKeys`, `Panel`, `PanelFocus` and `SoundToggle` (over the synth in
  `soundfx.js`); `kept.js` is storage.
- **Two sounds, and only two**, each a list of notes in `soundfx.js` with no assets. The new-game
  fanfare is the flash's `sound`, pushed by `GameLive` as `play-sound` so no reload can replay it.
  The sound toggle's chime is the browser's own.
- **PostgreSQL via Postgrex, one table**: `characters`, each run's state a single `jsonb` document.
- **One `GenServer` per character** under a `DynamicSupervisor` + `Registry`. Anything that mutates
  a character goes through its process, never straight to the database.
- **One LiveView, one dispatcher.** `GameLive` holds no game state and routes everything through
  `Access.pin_screen/2`. `Screens.screen/1` picks the page (start, town, gatekeeper, character,
  races, error), all in `Screens` until one needs its own module. `Screens.panels/3` lists a
  screen's panels, which `Layouts.app` draws inside `#screen`: one per screen, but one per lineage on
  the Chronicles and one per section on the character page. Every template starts with
  `<Layouts.app>`.
- **`Controls` holds what a page uses but does not own**: `<.panel>`, `<.data_table>`, `<.button>`,
  `<.select_action>` (a choice and the button acting on it, which is how a player moves), `<.alert>`
  and `<.flash_alert>`, `<.figure>`, `<.bar>`, `<.fault>`. `Layouts` holds the shell: `head`,
  `site_header`, the sidebar and `footer`, which `ErrorHTML` draws too.
- **The sidebar** (level and name, the name linking to `/character`, the vitals, then the Inventory)
  is one fixed-width `.side` column, drawn in town only. One breakpoint stacks it.
- **A new component, hook or shared control is written into this file in the change that adds it.**
  Before writing one, look here and in `Controls`, and extend what exists with an option instead.

### Debug-build tools

Dev and the e2e server only, never a release. Each is gated on `Version.debug_build?/0` twice, where
it is drawn and where it acts. Each has a test that turns the build off and finds nothing, and
`release.mjs` checks them against the real image. Keys go through `DevKeys`, which relays every key
pressed outside a text field (a letter, a Ctrl chord as `ctrl+<letter>`, anything else as `other`, a
lone modifier not at all), so anything between two keys breaks a sequence. A new sequence goes in
`GameLive`'s `@dev_sequences`. No dev tool goes in the town's dropdown: it is the game's.

| Key | Does | Test |
|---|---|---|
| Ctrl+Q | deletes the character; goes once there is a real way to start over | `quit_test.exs` |
| `adena` | +10,000 Adena every time; `Actions.dev_adena/1` refuses in a release | `dev_adena_test.exs` |
| `night`, `day` | `Clock.force/1` holds the node at that hour until the other word or a restart; pages redraw off `"world"`. A pinned time beats it | `dev_time_test.exs` |
| `half` | HP and MP to half, XP halfway to the next level; `Actions.dev_half/1` refuses in a release | `dev_half_test.exs` |
| `lvl` | the exact EXP the next level needs, through `Player.gain_experience/2` so both bars refill (rules §12); `Actions.dev_level/1` refuses in a release and at the last level | `dev_level_test.exs` |
| `maxlvl` | the same up to the last level, through `Actions.dev_max_level/1`; matched before `lvl` | `dev_level_test.exs` |
| (none) | game start comes with a name from `@dev_names` already written in | `dev_name_test.exs` |

## Working here

- **Done means `mix precommit`**, plus `mix e2e` for anything the browser renders: a screen, a hook,
  a selector, what an element *is*. A change that only moves colour values skips e2e; no suite can
  fail on a hex. ExUnit's coverage understates the web layer because the browser suites aren't
  instrumented.
- **Show a new test failing before claiming it passes.** Break what it covers, watch it go red, and
  restore with `git checkout` or `touch`. Never restore from a backup copy: it is older than the
  build, so Mix keeps the broken beam.
- **Never compile into `_build/dev` while the dev server is up.** Two writers corrupted beams and
  crashed a character mid-game. Use Tidewave's `project_eval`, a script with its own
  `MIX_BUILD_PATH`, or `:test`.
- **Ask the running app, through Tidewave.** `project_eval` for state (`:sys.get_state`,
  `:timer.tc`); `execute_sql_query` for `EXPLAIN (ANALYZE, BUFFERS)` on the statement Ecto actually
  sent, captured with a `:telemetry` handler on `[:mini_lineage, :repo, :query]`; `get_logs` for a
  request. A write goes through `Characters`, never `Repo`. A rehearsal at scale runs inside
  `Repo.transaction` with `Repo.rollback`, then `VACUUM FULL`, since rolled-back rows still bloat the
  indexes.
- **`.env.test` decides the browser suites' port, never `.env`.** `mix e2e` runs in `:dev` and gets
  away with it only because a Mix task doesn't start the app; adding `app.start` breaks it silently.
- **Node is `.nvmrc`'s and runs only Playwright.** CI reads it through `node-version-file`, `env.sh`
  through nvm, and `mix e2e` refuses any other. Never write a version into the workflow.
- **Anything that reaches the image is checked with `e2e/release.sh`**, as CI's publish job does: the
  Dockerfile, compose, `config/prod.exs` or `runtime.exs`, a migration, the release steps. It hands
  compose its own env file because `./.env` names the real database. If docker, buildx or compose is
  missing, install them (README, Docker) rather than skip.
- **No dev tool may loosen the CSP.** LiveDebugger runs on `:4007` with `browser_features?: false`, so
  it injects no script. Its assigns view shows `session_id`, a credential: never paste it. Tidewave is
  plugged in only on `/tidewave/*`, because it adds `'unsafe-eval'` and drops `frame-ancestors`.
- **Test fixtures live in `test/`**, never `priv/`, which ships.

### Tests

- **Not `async: true`** when a test touches the database (a character's GenServer comes from a
  `DynamicSupervisor`, so the sandbox needs shared mode), changes global state (Application env, an
  OS variable), or claims a registered name (every async module creating a character would post into
  its mailbox). Migrations commit DDL and end the sandbox, so `release_test` checks configuration
  rather than running one.
- **Never assert on a roll of the dice.** Pin with `Rng.put_source/1` or arrange the state so no roll
  changes the answer. A pin holds only in the process that pinned it, so pin a character's dice
  inside its GenServer, from a function handed to `Characters.mutate/2`. A drawn *string* is the same
  trap: fix the draw or match only what every draw shares.
- **Nor on the hour.** Night (rules §15) is the wall clock in a zone. `Clock.put_now/1` pins a UTC
  instant for the calling process and, through `$callers`, a LiveView it starts; a character's
  process is pinned inside `Characters.mutate/2`. Every stored time is UTC, and `:time_zone` decides
  night and nothing else. A browser suite never reads the night.
- **A property states what holds for every input; fixtures stay the contract with JavaScript.** A
  counterexample in a twinned formatter becomes a fixture row. Weight generators toward the boundary.
  Dice are a generated list of integers scaled into `[0, 1)` and cycled through `Rng.put_source/1`,
  never `float/1`, which grows with the size. StreamData is `:test` only, so `.formatter.exs` spells
  out its macros (`import_deps` fails in `:dev`).
- **A formatter with a client-side twin is held to a table.** `Format.short`/`shortFigure` and
  `Format.percent`/`percentFigure` (in `hooks/animated-values.js`) are deliberate copies, so a count
  never changes format mid-tween. Each pair reads `test/fixtures/short_format.json` or
  `percent_format.json`, from `format_test.exs` and `walkthrough.mjs`. Anything else both languages
  format gets the same before it gets a second copy.
- **Browser suites**: hand Playwright a function, never a string (the CSP refuses `eval`, and a
  `waitForFunction("…")` behind a `.catch` reads as a wait that returned). Read a figure's
  `data-value`, never its text, which is one frame of a 600ms count. Test what triggers an animation,
  never the animation itself.

## Rules

Each of these is here because it was got wrong once.

### The game

- **`docs/rules.md` is the base layer and the only authority**, in our own words: the eight starting
  sets and home villages, the six attributes, every stat and formula, resting, levels and the base
  outcomes. A number may be taken from L2 when a rule is written, whole and never rescaled beside
  numbers that were not; after that, nothing outside the document is consulted. `Rules` holds its
  tables and `Formulas` its formulas in its order, and `rules_test.exs` reads the tables back out of
  the document and works every example again, so a change to one is a change to both. A new system
  (classes, items, fighting, the world) starts as an entry in `docs/roadmap.md` and builds on the
  rules rather than quietly changing them. `Player.stats/1` runs the rules in order from the starting
  set and the level. A new character has no Adena and no items, in every environment.
- **`legacy/` is read, never run, and never updated.** It is the game as of `da4e37c`: the shops, the
  Battleground, the record and its Chronicle, the Halls, the Tome, class transfers, dyes, timed
  buffs, the other sounds and the cheat. Nothing there is compiled, formatted, tested or served, and
  nothing outside it imports, aliases or routes to it. A system rebuilt from it is rebuilt on the base
  layer with its rules and tests written fresh; its code and `legacy/AGENTS.md` are reference, not
  something to copy back.
- **What the player can see is what heals them.** `Player.regenerate/1` heals HP and MP by the rates
  `Player.auras/1` puts on the 🌿 aura, one per bar still short, each 3-second tick (rules §11), so
  there is no icon without healing and no healing without an icon. Night and the race perks (§15,
  §16) are auras the same way: `Player.conditions/1` derives them from the hour, race and town with
  the modifiers `Rules` gives, and `Player.stats/1` applies exactly those. A perk names its race in
  its own clause.
- **A line keeps its pronouns open until somebody reads it.** Narrative pools carry `{they} {them}
  {object} {their}` and nothing second-person. `Format.fill_template` leaves them alone (they aren't
  in the data map) and `Narrative.voiced/2` closes them at render: `true` for the run's own alert
  (`Narrative.alert/1`), `false` for anybody else. They/them shares your verb forms, but a line
  naming two people must keep its referents apart by construction. The game records no gender.

### Data

- **Mutable working state is a document; anything sorted on is a column.** A field that comes to be
  ranked or filtered becomes a GENERATED column over the document, never written by application
  code; under PG18 write `STORED`, or it is VIRTUAL and cannot be indexed. Anything that grows with
  play (a history, an inventory, a mailbox) gets its own table, or every save rewrites it.
- **A rule's table lives in code; Postgres holds what grows with play.** Towns, routes and fees, the
  EXP table, starting sets and modifiers are `Rules` attributes, changed by a commit, and the router
  builds each town's address from them at compile time. Size is no reason to move one. Once content
  reaches the hundreds (monsters, items, skills), each table moves to a data file under `priv/`
  loaded through `@external_resource`, still in git and read back by a test. Content goes into
  Postgres only when it must change without a deploy, decided when such a feature exists.
- **A character has two ids, never to be confused.** `id` is public and the only one a page shows or
  links. `session_id` is the cookie and a credential: a public id that worked as a session would let
  anyone play anyone. Anything listing characters selects into plain maps, never `%Record{}`, which
  carries `session_id`, and says `active` ("has a session"), never the session. The session names the
  BROWSER, not the run, so it outlives the run's process and every tab.
- **Writes follow the player, not the clock.** What the player did (today: creating the character) is
  written before they are told it worked. Resting is buffered and rides along with the next write,
  the 60-second backstop, or `terminate/2`. `Characters.Server` derives this from the struct
  (anything outside `@buffered` changed), never from a call site, which can forget.
- **A visitor is never written.** A browser that hasn't chosen a lineage lives only in its process,
  and the tick skips a run that hasn't started, so nothing marks it dirty. Hence `characters` has no
  row without a race (`visitor_test.exs`).
- **A run nobody comes back to goes missing, never deleted.** The 30-day retirement clears its session
  and leaves its row.
- **The registry can name a process that has just stopped.** `Characters.call/3` reads the registry
  directly, which keeps every call off the `DynamicSupervisor`, whose loop runs two queries to start a
  character. A lookup can see an entry whose `DOWN` is still queued, so the RETRY goes through the
  supervisor, by which time the stale entry is gone.
- **Dropping a column drops every index that mentions it, WHERE clauses included.**
  `schema_test.exs` names the indexes the game cannot go without; add yours there. A query-plan
  assertion can't do this job, because Postgres rightly scans a test's few rows.
- **A round trip costs ~0.8ms, and the query usually less.** Prefer one statement to a clever plan.
  `EXPLAIN ANALYZE` says nothing about the wire, so time the wall clock, and time the Ecto path that
  ships rather than hand-written SQL (`Repo.query!` re-plans every call).

### Web

- **The URL is where you are.** A character stands in one town (rules §14), stored as `location`.
  Each open town and its Gatekeeper have literal routes generated from the town table, never a
  pattern. `/` is game start for a visitor and, for a character, a patch to its town: `GameLive`
  compares the pinned place's address with the one asked for, not the screen alone. A place is
  `{screen, town}`. A new place to stand (a shop, a hunting ground) gets its own URL when built; a
  state that happens to you does not.
- **`Access.pin_screen/2` gates what may be DONE, never what may be read.** `races` and `error` carry
  no action, so its first clause lets every state reach them. The rest decide only screens that can
  be acted on: a character is in its town, at that town's Gatekeeper or on its own page; a visitor is
  at game start.
- **Do not widen a guard to make something work.** `Access.pin_screen/2`'s clauses, `e2e/reset.sh`'s
  refusal of the database `.env` names, `Actions.start/4`'s preconditions: each is the boundary, and a
  test asserts what it still refuses. If one is in the way, what you are building is probably wrong.
- **There is no catch-all route.** A glob is a soft 404 that discards the address and answers a
  mistyped stylesheet with HTML. Phoenix raises for what it doesn't route and `ErrorHTML` draws it in
  the game's shell. `pin_screen` redirects stay: not being allowed somewhere is not the somewhere not
  existing.
- **What a fault page says depends on the build.** A debug build shows the whole thing,
  `Exception.format/3` on the kind, reason and stack; a release shows none of it. The gate is
  `Version.debug_build?/0`, deliberately not `release?/1`, or an image built without APP_VERSION
  would serve traces to players. A 404 gets no trace either way. Both draw through `<.fault>`.
- **The banner is the way home.** It links `/` on every page, the error page too; no page has a back
  link of its own.
- **A screen showing somebody's figures is pushed to, not polled.** `"character:#{session}"` is the
  browser's own topic, keyed by a secret so nobody can watch anybody else, and a second tab follows
  through it. A topic others may follow is keyed by the PUBLIC id and followed only on the screen
  that draws it. Nightfall stores nothing: `GameLive` wakes itself at `Clock.next_boundary/1` and
  redraws. `Server.run/3` broadcasts AFTER it persists, so a reader answering a push finds the write.
- **The cookie is legible only to the secret that signed it.** dev and prod read the same `.env`, so
  `config/runtime.exs` gives both the same `SECRET_KEY_BASE`; dev falls back to the one committed in
  `config/dev.exs`.

### Components

- **Every panel is `Controls.panel/1`**: the card, the header band, the title (always an h2), the
  body. Options are `icon` (an emoji before the title), `collapsible` and `collapsed`. `id` names the
  PANEL, which its hook needs; every other attribute lands on the BODY. A screen is addressed by
  `#screen`, which carries `PanelFocus` and the data attributes browser tests read. A panel takes a
  hook only when something in it moves, so the error page, with no LiveView, needs no JavaScript.
- **A collapse is the reader's, not the template's.** `aria-expanded` is rendered once for the
  opening state, then belongs to the `Panel` hook, re-applied on every `updated/0`. It is the whole
  state: CSS hides a folded body off it, never a `hidden` attribute, so a layout with room keeps it
  open before any script runs and tells the hook with `--folds: 0`, where the header is disabled. The
  header band is a BUTTON inside the h2, never a link (Space scrolls a link, and `PanelFocus` refuses
  to focus one). Opening by hand scrolls the panel into view; restoring or patching never moves the
  page. The chevron's transition waits for the `data-ready` the hook sets two frames in. A side
  panel folds only if marked `.folds`: today only the Inventory, on a phone, opening unfolded.
- **What the reader chooses is kept as `<kind>:<id>` through `hooks/kept.js`**, whose `recall` and
  `keep` are the only code touching `localStorage`: `panel:<id>` for a fold, `sound:effects` while
  sound is off. A new thing that remembers takes a kind and writes no storage code. Hand a kind to the
  server only when it must know it to render.
- **Every button is `Controls.button/1`**, the only writer of `btn`. Today it is always a `<button>`,
  because it does something; one that goes somewhere is an `<a>` (a `patch` option, when a screen
  first needs it), never a link restyled as a button or the reverse. `variant={:secondary}` serves
  `<.select_action>` until something is picked; danger and small come back from `legacy/` when
  needed. `PanelFocus` gives a panel's first control the keyboard on arrival, so a destructive control
  is marked `data-no-autofocus`.
- **Every alert is `Controls.alert/1`**, `kind` `:info` or `:danger`, anything else landing on the
  `div` (`alert_variants_test.exs`). None is dismissed: what an action says, a refusal included, is
  its flash, dropped on the next arrival unless the action itself moved you there.
- **Every table is `Controls.data_table/1`**: the container, header row and `<table>`, with the rows
  the caller's `<tbody>` and other attributes on the `<table>`. A sort is the server's, never the
  DOM's, which a patch would undo. `legacy/` has the sortable one.
- **Every figure counts; only names and dates jump.** A number the player can watch change is a
  `<.figure>`, animated by `AnimatedValues` hooked once over whatever contains them. It writes
  `data-value` and the text from one value, and `format={:short}` sets both the short form and the
  `data-format` its frames count in. Adena counts short, and so does XP at the last level. Frames keep
  the tenth the settled value drops, so "2.0k" doesn't narrow to "2k" and jump the line. Animate a
  figure even where it can only move by one today: the count reads its distance from the delta, and
  a +1 tween is a 137ms delay, not a flicker.
- **A bar is a figure against its cap.** `Controls.bar/1` draws track, fill and figures from `value`
  and `of`, with `aria-valuetext` on a `meter` (HP, MP) or a `progressbar` (XP), so width, text and
  speech agree. Without `of` it is the figure alone in a full track, as XP is at the last level.
  `wraps` names what going round is (the level, for XP), and `AnimatedValues` refills from empty
  rather than sliding back. `label` is drawn inside on the left. `format={:percent}` writes one figure,
  the floored hundredths of `of`, keyed `<key>-percent`. A bar leaves its class to the hook through
  `JS.ignore_attributes`, so a patch can't cut off a running sweep.
- **`class` and `style` render even when nil**, as `class="panel "` and `style=""`. Build them before
  the tag (`classes/1` in `Controls`) or spread a keyword list.

### Prose and markup

- **The game's prose joins its clauses rather than splitting them with an em dash**: a dash in a
  sentence a player reads becomes `because`, `and` or `nor`. Comments and docs are exempt.
- **Write a named entity where one exists**: `&amp;` `&copy;` `&ndash;` `&bull;` `&nbsp;` `&mdash;`
  `&hellip;`. Everything else, every emoji included, is written as it is.
- **An anchor wraps its text and nothing else.** A newline inside renders as an underlined space, so
  keep the content flush against `>` and `</`, and name a long label above the `~H`. Buttons are
  exempt.
- **One h1**, the banner's "Mini Lineage", on every page. Every panel title is an h2, a section
  inside a panel an h3. Nothing skips a level.

### Config and release

- **An empty environment variable is not an absent one.** `System.get_env("DB_PORT", "5432")` returns
  `""`, and compose passes a missing key as empty, so every `${VAR}` it forwards needs `:-default`.
- **Ownership is set as files land**: `COPY --chown=app:app`. A later `chown -R` writes a second copy
  of the release into its own layer. `/app` itself still needs chowning.
- **Migrations ship inside the image.** A stale image's "Migrations already up" is about the
  migrations it carries; rebuild before believing it.
- **`compile_env` only for values constant per environment.** `:build_label` qualifies;
  `:app_version` moves with every commit, and baking it makes Mix refuse every task after the next
  one. Read a moving value with `Application.get_env/2`, and put a build-time requirement in a release
  step in `mix.exs`.
- **A setting an environment overrides is defaulted in `config.exs` and nowhere else**, read with
  `compile_env!` or `fetch_env!` and never a default of its own, so a missing key fails at compile or
  boot. Only `:app_version` is optional. A value no environment changes is a rule of the game, in
  `Constants`.

### Comments

One to three lines, why and not what: a constraint, a trap, a decision that looks wrong until you
know why. Never narrate the line, restate the identifier, or tell how the bug was found. Needing more
than three lines means the knowledge belongs in this file. Moduledocs may run to a short paragraph. A
comment citing a measurement expires when what it was measured against moves.

## Elixir and Phoenix reminders

- No `list[i]` (use `Enum.at/2` or a match) and no `struct[:field]` (use `struct.field`).
- No `else if`: use `cond` or `case`. Bind the result of an `if` or `case`; a rebinding inside it
  is lost.
- One module per file. No `String.to_atom/1` on input. A predicate ends in `?`; `is_` is for guards.
- HEEx: `{...}` in attributes and for values, `<%= %>` for block constructs in a body. A class list
  is `[...]`, with any `if(..., do: ..., else: ...)` in parens. Comments are `<%!-- --%>`. Lists come
  from `:for` or `<%= for %>`, never `Enum.each`.
- Forms: `to_form/2` assigned in the LiveView, `<.form for={@form} id="...">`, and inputs written by
  hand from `@form[:field]`. Never touch a changeset in a template. Programmatic fields stay out of
  `cast`.
- `<.link navigate>` and `<.link patch>`, `push_navigate` and `push_patch`; never `live_redirect` or
  `live_patch`.
- A `phx-hook` needs a unique id, and `phx-update="ignore"` if the hook owns its DOM.
- In tests: `start_supervised!/1`; no `Process.sleep/1` or `Process.alive?/1` (monitor and
  `assert_receive` the `:DOWN`, or `:sys.get_state/1` to synchronise); assert with `element/2` and
  `has_element?/2` on ids, never on raw HTML.
- `mix ecto.gen.migration name_with_underscores` for a migration.
