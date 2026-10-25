Mini-Lineage Remastered: a text-based RPG in Elixir, Phoenix LiveView and OTP. What is written here
beats any general Phoenix habit. How the game is drawn (type, layout, classes, colour) is in
[docs/design.md](docs/design.md): read it before touching a stylesheet, a class or a control's look.

## What exists

- **The live game is the base layer and the first hunt**: character creation, the towns of rules §14
  with their Gatekeepers and the sidebar, each village's hunting ground (rules §17 to §21:
  the one-click fight in `Hunt`, fought on one line where a pull or an aggressive monster sets the
  distance, `Actions.hunt/1`, the last fight fought there in a panel of its own under the ground's,
  `#fight`, read back from `encounters` on every arrival and drawn by `<.fight_log>` an entry a row
  as legacy's Chronicle was, and death: the run stays on the ground it fell on, a 👻 ghost wearing
  no other aura and mending nothing, its ground's panel headed 🪦 Game Over (as are the page title
  and the inventory's way back) and telling its end in a line drawn as it fell
  (`death_line`), its fight ending in Defeat, offering the Monument and Play Again,
  `Actions.restart/1`, and refused every other action),
  each village's traders (`/<village>/traders`), four by name
  on three pages (the jeweller and the grocer keep the Magic Trader together) and Sell
  (`/<village>/traders/<weapon-trader|armour-trader|magic-trader|sell>`, each set shown its path's goods by
  `Rules.stock/2`), and the inventory beside its Combat
  Stats (rules §23 and §24: `Shop`, the items table, `/inventory`), potions and the Battle Orders
  under the ground's Fight Log (rules §26, §20: `Actions.potion_at/2`, `heal_at/3`, `use_skill/3`,
  a `<.stepper>` for each share, a `<.switch>` for each skill, and a footer row of the SP the
  guild spends beside 🧹 Reset to Default, `reset_orders/1`, back to `Player.default_orders/0`), the
  Buffs & Debuffs panel, and the home village's guild, where the set's own trainers teach (rules §25: `Actions.learn/3`,
  `/<village>/<guild>`, named per set by `Rules.guild/1`, its lessons on an Active and a Passive shelf,
  a character's `skills` and `sp`), `/character`, the Chronicles of Ancestry at `/chronicles-of-ancestry`, the Monument of Heroes
  (the Halls, in code) at `/monument-of-heroes`, reached from game start, a fallen run's ground and every
  town's Travel (its obelisk stands in each), and the error page. Everything the game was before that is
  in `legacy/` (see Rules).
- **Not here, so don't reach for it**: `core_components.ex` (no `<.icon>`, `<.input>` or
  `<.flash_group>`; every control is hand-written HEEx in `lib/mini_lineage_web/components/`); an
  HTTP client (no `Req` or `httpoison`; the zone database is `tz`, never `tzdata`, which brings
  hackney, and `tz`'s updater stays unused); authentication (a signed session cookie ties a browser
  to a character and nothing else); LiveView streams (one character's state is one assign);
  colocated hooks.
- **Hooks**: `app.js` imports them from `assets/js/hooks.js`, which holds nothing but that list and
  the formatter twins it re-exports (see Tests). Each
  is its own file under `assets/js/hooks/`; a `ColocatedHook` would compile and never run. They are
  `AnimatedValues`, `DevKeys`, `EffectTimers`, `Panel`, `PanelFocus`, `SelectAction`, `SoundToggle`
  (over the synth in `soundfx.js`), `Stamp` and `Table`; `kept.js` is the kept cookie (see Components).
- **Five sounds**, each a list of notes in `soundfx.js` with no assets. All but the toggle's are
  pushed by `GameLive` as `play-sound` (`sound/1`), so no reload can replay one, and one action
  plays one sound at most: a fight is one click however many blows or potions it holds.

  | Sound | Notes | Plays on | Decided by |
  |---|---|---|---|
  | `start` | D4 F#4 A4 D5 | a character made | the flash's `sound` |
  | `death` | sawtooth sliding 260 to 45 Hz | a run's end | the flash's `sound` |
  | `level` | C5 E5 G5 C6, the last ringing | a new level (the gold alert) | the flash's `levelled` |
  | `success` | E4 A4 E5 | any green alert | `type: :success`; a kill is drawn on the page, so it is silent |
  | `toggle` | B5 E6 | sound switched on | the browser, unasked |
- **PostgreSQL via Postgrex, three tables**: `characters`, each run's state a single `jsonb` document,
  `items`, its inventory, and `encounters`, every fight it fought (see Data).
- **One `GenServer` per character** under a `DynamicSupervisor` + `Registry`. Anything that mutates
  a character goes through its process, never straight to the database. The registry entry's value
  is `{id, watched?}`, which `Characters.online/0` reads for the Halls' dot.
- **`Board` is the Halls**: a view of `characters` over generated columns, one `UNION ALL` statement
  for every board (overall and each lineage, top 25), coalesced into one read per 500ms and pushed on
  `"board"` only when it moved. `:start_board` is off in test, where `Board.current/0` computes in
  the caller; its own tests start it.
- **One LiveView, one dispatcher.** `GameLive` holds no game state and routes everything through
  `Access.pin_screen/2`. `Screens.screen/1` picks the page (start, town, gatekeeper, hunt, trader
  and its pages, guild, inventory, character, races, highscores, error), all in `Screens` until one
  needs its own module; the Halls have
  `Screens.Halls`. `Screens.panels/4` lists a
  screen's panels, which `Layouts.app` draws inside `#screen`: one per screen, but one per lineage on
  the Chronicles, one per section on the character page, Inventory and Combat Stats on the
  inventory, on the guild's a Learned Skills panel only once something is learned, and on the
  ground the Fight Log only once a fight is held there, which is what its fourth argument is for,
  then the Battle Orders, which a fallen run has none of. A panel is first tier (the vital panel and each screen's first, where a
  run is read and played) or second tier (what stands beside or under one: the Consumables, the
  Inventory, the guild's Learned Skills, the inventory's Combat Stats, the Battle Orders), which is
  `collapsible` at every width under an `id` its kept fold is named by. The character page's
  sections are its own, and the Fight Log the ground's, so neither folds. `GameLive` lists them
  again whenever the view is rebuilt. Every LiveView template starts with
  `<Layouts.app>`; `ErrorHTML` builds its own from the shell's parts.
- **`Controls` holds what a page uses but does not own**: `<.panel>`, `<.data_table>`, `<.button>`,
  `<.select_action>` (a choice and the button acting on it, which is how a player moves and acts:
  never a button per table row; a screen reads as a table and acts through one dropdown),
  `<.stepper>` and `<.switch>` (a setting, see Components), `<.alert>`
  and `<.flash_alert>`, `<.fight_log>` (rules §20's entries, in the ground's Fight Log, `#fight`), `<.figure>`, `<.bar>`, `<.stamp>` (when something happened, see Components), `<.fault>`, and `item_label/1`, an item as every
  page and dropdown names it (emoji, name, then ✋ or 👐 for what a weapon or shield takes in hand). `Layouts` holds the shell: `app`,
  `head`, `site_header`, the sidebar and `footer`; `ErrorHTML` reuses `head`, `site_header` and
  `footer`.
- **The sidebar** (the vital panel, `.vital-panel`: level and name, the name linking to
  `/character`, the bars, HP's and MP's rows pulsing in their bar's hue under a quarter, a fallen
  run's neither, its band wearing ☠️ for its race; then the
  Consumables, each stack carried with its count, and no panel at all while none is; then the
  Inventory, its Adena beside an Open link to `/inventory`, Close back on the inventory itself) is one fixed-width `.side` column, drawn
  in town and beside the inventory. One breakpoint stacks it.
- **A new component, hook or shared control is written into this file in the change that adds it.**
  Before writing one, look here and in `Controls`, and extend what exists with an option instead.

### Debug-build tools

Dev and the e2e server only, never a release. Each is gated on `Version.debug_build?/0` twice, where
it is drawn and where it acts. Each has a test that turns the build off and finds nothing, and
`release.mjs` checks them against the real image. Keys go through `DevKeys`, which relays every key
pressed outside a text field (a letter as itself, anything else, a chord included, as `other`, a
lone modifier not at all), so anything between two keys breaks a sequence. A new sequence goes in
`GameLive`'s `@dev_sequences`. No dev tool goes in the town's dropdown: it is the game's.

| Key | Does | Test |
|---|---|---|
| `quit` | deletes the character, its row, items and encounters; kept by choice, death notwithstanding, for trying every set from one browser | `quit_test.exs` |
| `adena` | +10,000 Adena every time; `Actions.dev_adena/1` refuses in a release | `dev_adena_test.exs` |
| `night`, `day` | `Clock.force/1` holds the node at that hour for exactly five minutes or until the other word, the 🌙 counting them down with no "until dawn"; then the real hour is back, a real night with its own countdown. Pages redraw off `"world"` and wake when the hour is given back. A pinned time beats it | `dev_time_test.exs` |
| `sp` | +10,000 SP every time, to try the trainer; `Actions.dev_sp/1` refuses in a release | `dev_sp_test.exs` |
| `half` | HP and MP to half, XP halfway to the next level; `Actions.dev_half/1` refuses in a release | `dev_half_test.exs` |
| `frail` | 1 HP, so the browser suites can reach a death; `Actions.dev_frail/1` refuses in a release | `dev_frail_test.exs` |
| `lvl` | the exact EXP the next level needs, through `Player.gain_experience/2` so both bars refill (rules §12); `Actions.dev_level/1` refuses in a release and at the last level | `dev_level_test.exs` |
| `maxlvl` | the same up to the last level, through `Actions.dev_max_level/1`; matched before `lvl` | `dev_level_test.exs` |
| `twink` | puts the run back to one saved state however often it is typed: Level 15, every lesson its trainer teaches by then, the dearest of every line its village sells its set (a one-handed and a two-handed sword or staff both), the kit's line in hand and the shield, only when a one-handed weapon is among them, worn beside one, 30 Lesser Healing Potions, 10,000 SP, 50,000 Adena and the default Battle Orders, every skill in use, and nothing else carried, the starting kit included; a piece still carried keeps its id; `Actions.dev_twink/1` refuses in a release | `dev_twink_test.exs` |
| (none) | game start comes with a name from `@dev_name_heads` and `@dev_name_tails` already written in | `dev_name_test.exs` |

## Working here

- **Balance is measured, not guessed.** `bench/ladder.exs` plays every set up its village's ladder
  through the game's own actions (hunt, rest, buy, sell, train) with seeded dice, as a player would:
  its own weapon's line, a shield only beside a one-handed sword or staff. Each one-handed path runs
  again off-meta and is flagged when it beats the meta, since a build the rules let win is a rule to
  fix. Anything that moves a fight's numbers, a price, a reward or the trainer is measured before and
  after against the bar in [docs/direction.md](docs/direction.md), and
  [docs/balance.md](docs/balance.md) is rewritten from the reading; the `balance-study` skill has the
  steps. A change that fails the bar is reported, never tuned quietly.
- **The dev database is not player data.** Its rows are the owner's test runs and e2e traffic. Use it
  to see what a document looks like or to check a plan, never to reason about progression, deaths or
  balance: that comes from `Formulas`, `Hunt`, `Rules` or the bench, named as the source.
- **Done means `mix precommit`**, plus `mix e2e` for anything the browser renders: a screen, a hook,
  a selector, what an element *is*. A change that only moves colour values skips e2e; no suite can
  fail on a hex. ExUnit's coverage understates the web layer because the browser suites aren't
  instrumented.
- **Show a new test failing before claiming it passes.** Break what it covers, watch it go red, and
  restore with `git checkout` or `touch`. Never restore from a backup copy: it is older than the
  build, so Mix keeps the broken beam. A file with uncommitted work is not restored with `git
  checkout`, which wipes the work too: reverse the exact `sed`, then `touch`.
- **Never compile into `_build/dev` while the dev server is up.** Two writers corrupted beams and
  crashed a character mid-game. Use Tidewave's `project_eval`, a script with its own
  `MIX_BUILD_PATH`, or `:test`. Claude Code's `.claude/hooks/dev_build_guard.py` refuses a Mix
  command that builds `:dev` (compile, run, eval, `phx.server`, `ecto.*`…) while something listens
  on the dev server's `PORT`; `mix e2e`, `test` and `precommit` pass, as does any `MIX_ENV=test`.
- **What every agent should know lives in the repo**: this file for rules, `docs/` for the game's
  why, and `.claude/` for Claude Code: the committed `settings.json` and its hooks, and `skills/` for
  procedures (`balance-study`, `new-page`), each moved out of here rather than copied, so the two
  never drift. A personal memory holds only what is about one person or one machine.
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

- **A browser test before a unit test.** Every serious bug so far (a CSP rewriting redirects, a swap
  wiping the main panel, a stale-code watcher) was browser-only, and the old stack's 100% line
  coverage saw none of them. A unit test holds a contract (the rules core in `rules_test.exs`, the
  twinned formatters' fixtures, a component's markup); what a player sees and does is proven in the
  browser.
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
  two things: night, and every day, hour and year the game draws, a `<.stamp>`'s, the banner's
  clock and the footer's year (`Clock.local/1`), never `Date.utc_today/0`, so a date is the
  server's from the first draw. The suites play UTC; a test of what a zone changes puts one for its
  module with `MiniLineage.Zone.put/1` (never async) and picks an instant whose day the zone moves.
  A browser suite never reads the night.
- **A property states what holds for every input; fixtures stay the contract with JavaScript.** A
  counterexample in a twinned formatter becomes a fixture row. Weight generators toward the boundary.
  Dice are a generated list of integers scaled into `[0, 1)` and cycled through `Rng.put_source/1`,
  never `float/1`, which grows with the size. StreamData is `:test` only, so `.formatter.exs` spells
  out its macros (`import_deps` fails in `:dev`).
- **A formatter with a client-side twin is held to a table.** `Format.short`/`shortFigure`,
  `Format.percent`/`percentFigure` and `Format.tenths`/`tenthsFigure` (in
  `hooks/animated-values.js`, the last for a figure in tenths: a rate such as Critical or Block, or a
  cast or reuse time) are deliberate copies, so a count never
  changes format mid-tween, and so are `Format.countdown`/`timerLabel` and
  `Format.remaining`/`remainingLabel` (in `hooks/effect-timers.js`) and `Format.stamp`/`stampLabel`
  (in `hooks/stamp.js`). Each pair reads `test/fixtures/short_format.json`, `percent_format.json`,
  `tenths_format.json`, `effect_timer.json` or `stamp_format.json`, from `format_test.exs` and
  `walkthrough.mjs`. Anything else both
  languages format gets the same before it gets a second copy.
- **Browser suites**: hand Playwright a function, never a string (the CSP refuses `eval`, and a
  `waitForFunction("…")` behind a `.catch` reads as a wait that returned). Read a figure's
  `data-value`, never its text, which is one frame of a 600ms count. Test what triggers an animation,
  never the animation itself.

## Rules

Each of these is here because it was got wrong once.

### The game

- **`docs/rules.md` is the base layer and the only authority**, in our own words: the eight starting
  sets and home villages, the six attributes, every stat and formula, resting, levels and the base
  outcomes. A Lineage II name or number comes from `docs/canon/`, the reference and not a plan:
  taken whole when a rule is written, never rescaled beside numbers that were not, and from then on
  the rule is the authority. One the canon lacks is researched into it first, never guessed. `Rules`
  holds its tables and `Formulas` its formulas in its order, and `rules_test.exs` reads the tables
  back out of the document and works every example again, so a change to one is a change to both. A
  new system (classes, items, fighting, the world) starts as an entry in `docs/roadmap.md` and
  builds on the rules rather than quietly changing them. A rule may be written ahead of what uses
  it, taken whole from the canon for a roadmap entry (§19's NPC Windstrike - Slow 2 waits for the
  Ruins of Despair's Zombie Warrior), so an audit reads an unused rule as planned, never dead, and
  `Rules` keeps it as the document does. `Player.stats/1` runs the rules in order
  from the starting set and the level. A new character has no Adena and wears its set's kit (rules
  §23), in every environment.
- **`legacy/` is read, never run, and never updated.** It is the game as of `da4e37c`: the shops, the
  Battleground, the record and its Chronicle, the Halls, the Tome, class transfers, dyes, timed
  buffs, the other sounds and the cheat. Nothing there is compiled, formatted, tested or served, and
  nothing outside it imports, aliases or routes to it. A system rebuilt from it is rebuilt on the base
  layer with its rules and tests written fresh; its code and `legacy/AGENTS.md` are reference, not
  something to copy back.
- **What the player can see is what heals them.** `Player.regenerate/1` heals HP and MP by the rates
  `Player.auras/1` puts on its auras (the 🌿 one per bar still short, 🧘 Relax), each 3-second tick
  (rules §11), so there is no icon without healing and no healing without an icon. Night, the race
  perks (§15, §16) and the auras a character raised (§19, kept in `buffs` to the millisecond they
  fade) are auras the same way: `Player.conditions/1` derives them with the modifiers `Rules` gives,
  and `Player.stats/1` applies exactly those. A perk names its race in its own clause. A mastery
  (§19, a `passive`) is no aura and has no aura icon: `Player.stats/1` adds (or, with `times`,
  multiplies by) the bonuses `Rules` gives its line, in order, before any aura, and its row on
  Learned Skills says so. A skill whose lines differ by path keeps one name and is looked up with
  `Rules.skill/3` (Weapon Mastery: a Fighter's P. Atk., a Mystic's M. Atk.), never a second name.
- **A line keeps its pronouns open until somebody reads it.** Narrative pools carry `{they} {them}
  {object} {their}` (`{Their}` opening a sentence) and nothing second-person. `Format.fill_template` leaves them alone (they aren't
  in the data map) and `Narrative.voiced/2` closes them at render: `true` for the run's own alert
  (`Narrative.alert/1`), `false` for anybody else. They/them shares your verb forms, but a line
  naming two people must keep its referents apart by construction. The game records no gender.

### Data

- **Mutable working state is a document; anything sorted on is a column.** A field that comes to be
  ranked or filtered becomes a GENERATED column over the document, never written by application
  code; under PG18 write `STORED`, or it is VIRTUAL and cannot be indexed. Anything that grows with
  play (a history, an inventory, a mailbox) gets its own table, or every save rewrites it. The
  inventory is `items`, written by `Store.save/4` in the character's transaction only when the list
  moved (`Server` compares it with what it last wrote), and `e2e/reset.sh` truncates it with
  `characters`. A potion (rules §26) is one row with a `count`; every other item counts 1. A fight
  is a row of `encounters`, its log and outcome a `jsonb` document and its `ground` generated, carried
  on the struct as `encounter` until `Store.save/4` writes it in the same transaction and `Server`
  drops it.
- **Every table ends on its timestamps.** Postgres appends an ALTER'd column after them, so a new
  column, generated or not, goes into the one migration, `20261015000000_initial_schema.exs`, at
  its place before `timestamps`, and `schema_test.exs` fails a table that ends otherwise. The
  schema stays one migration until `next` is first deployed: until then a database is rebuilt, not
  migrated (`MIX_ENV=test mix do ecto.drop, ecto.create, ecto.migrate`, and the dev database by
  hand). From the first deploy on a change is a migration of its own, and the rule is the order
  the columns were declared in.
- **A rule's table lives in code; Postgres holds what grows with play.** Towns, routes and fees, the
  EXP table, starting sets and modifiers are `Rules` attributes, changed by a commit, and the router
  builds each town's address from them at compile time. Size is no reason to move one. Once content
  reaches the hundreds (monsters, items, skills), each table moves to a data file under `priv/`
  loaded through `@external_resource`, still in git and read back by a test: the monsters are
  `priv/game/monsters.csv`, the items `priv/game/items.csv` and the trainers' lessons
  `priv/game/trainer.csv`, held to rules §18, §24 and §25 by `rules_test.exs`. Content goes into Postgres only when it must change without a deploy, decided
  when such a feature exists.
- **A character has two ids, never to be confused.** `id` is public and the only one a page shows or
  links. `session_id` is the session cookie and a credential: a public id that worked as a session
  would let anyone play anyone. Anything listing characters selects into plain maps, never `%Record{}`, which
  carries `session_id`, and says `active` ("has a session"), never the session. The session names the
  BROWSER, not the run, so it outlives the run's process and every tab.
- **Writes follow the player, not the clock.** What the player did (a start, a hunt, a trade, a lesson, an order) is
  written before they are told it worked. Resting is buffered and rides along with the next write,
  the 60-second backstop, or `terminate/2`. `Characters.Server` derives this from the struct
  (anything outside `@buffered` changed), never from a call site, which can forget.
- **A visitor is never written.** A browser that hasn't chosen a lineage lives only in its process,
  and the tick skips a run that hasn't started, so nothing marks it dirty. Hence `characters` has no
  row without a race (`visitor_test.exs`).
- **A run nobody comes back to goes missing, never deleted.** The 30-day retirement clears its session
  and leaves its row. It counts from the later of the last write and `seen_at`, which
  `Characters.Server` writes whenever a started run's first tab opens or its last closes, and it
  spares every run online, so a player who only looks never loses one. The cookie's own 30 days
  restart on every page load (`CharacterSession` puts the session each time).
- **A run that dies is over, never deleted** (rules §21). It is written `dead` with its `killer`,
  `fell_at` (the ground, not the time), `died_at` (its UTC millisecond, the Halls' generated
  `died_at` column) and `death_line` like any other write, and stays the browser's until Play Again. Then
  `Characters.Server`, seeing a fallen run come back unstarted, writes it and clears its session in
  one statement (`Store.retire/2`), and goes on as the browser's next, unstarted character under a
  fresh id, so no process stop races the registry. The row stays for the Halls.
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
  Each open town, its Gatekeeper, its ground (`/<town>/<ground>`), a village's traders and their
  pages (`/<town>/traders/<page>`) and guild, and each lineage's board (`/monument-of-heroes/<lineage>`)
  have literal routes generated from the rules tables, never a pattern. `/` is
  game start for a visitor and, for a character, a patch to its town (a fallen run's ground): `GameLive` compares the pinned
  place's address with the one asked for, not the screen alone. A place is `{screen, town}`. A new
  place to stand (a shop, a hunting ground) gets its own URL when built; a state that happens to you
  does not.
- **An address says what its link says.** Each segment is `Format.slugify/1` of the name the game
  draws for that place, derived and never written: a town's and a ground's in `Rules`
  (`/town-of-gludio`), a guild's (`/talking-island-village/mystics-guild`, so a run is sent on to
  its own set's through `Paths.for_screen/2`), a lineage's plural as its filter reads
  (`/monument-of-heroes/dark-elves`), and a page's own name in `Paths.names/0`, which `Screens`
  heads the page with (`/traders/weapon-trader`). The router builds every route through `Paths`,
  and `paths_test.exs` holds each segment to a name. A screen's id is internal and stays as it is
  (`highscores`, `races`, `trader-weapon`); a town is referred to by its slug elsewhere.
- **`Access.pin_screen/2` gates what may be DONE, never what may be read.** `races`, `highscores`
  and `error` carry no action, so its first clauses let every state reach them; the Halls keep their
  lineage filter in the place's second half. The rest decide only screens that can be acted on: a
  character is in its town, at that town's Gatekeeper, on that town's ground or at its traders if it
  has them, at its home village's guild, or on its own character or inventory page; a fallen run is
  on the ground it fell on, or on its own character or inventory page; a visitor is at game start.
- **Do not widen a guard to make something work.** `Access.pin_screen/2`'s clauses, `e2e/reset.sh`'s
  refusal of the database `.env` names, `Actions.start/4`'s preconditions: each is the boundary, and a
  test asserts what it still refuses. If one is in the way, what you are building is probably wrong.
- **There is no catch-all route.** A glob is a soft 404 that discards the address and answers a
  mistyped stylesheet with HTML. Phoenix raises for what it doesn't route and `ErrorHTML` draws it in
  the game's shell. `pin_screen` redirects stay: not being allowed somewhere is not the somewhere not
  existing.
- **What a fault page says depends on the build.** A debug build shows the fault,
  `Exception.format/3` on the kind, reason and stack on `ErrorHTML`'s page, and the exception's
  message or the process's exit reason on the game's error screen; a release shows none of it. The gate is
  `Version.debug_build?/0`, deliberately not `release?/1`, or an image built without APP_VERSION
  would serve traces to players. A 404 gets no trace either way. Both draw through `<.fault>`.
- **The banner is the way home.** It links `/` on every page, the error page too; no page has a back
  link of its own.
- **A screen showing somebody's figures is pushed to, not polled.** `"character:#{session}"` is the
  browser's own topic, keyed by a secret so nobody can watch anybody else, and a second tab follows
  through it. A topic others may follow is keyed by the PUBLIC id and followed only on the screen
  that draws it. Nightfall stores nothing: `GameLive` wakes itself at `Clock.next_boundary/1` and
  redraws. `Characters.Server` broadcasts AFTER it persists, so a reader answering a push finds the write.
- **The first draw is the one the reader sees.** Anything a reload must keep (a fold, a sort, the
  sound) is read from the request and served as it was left, never put right by a hook once the
  page connects: drawn wrong and fixed later, every reload moves. The walkthrough compares the page
  as served with the page as shown (`servedShown`).
- **The session cookie is legible only to the secret that signed it.** dev and prod read the same `.env`, so
  `config/runtime.exs` gives both the same `SECRET_KEY_BASE`; dev falls back to the one committed in
  `config/dev.exs`.

### Components

- **Whatever moves beside text moves by a painted property**, an animation, a transition and a
  hover alike: `left`, `color`, `background-position`, a registered custom property. Where only
  `transform`, `opacity` or `filter` will do it runs inside an `overflow: clip` of its own, and
  nothing fills `forwards` (`b88e2ac`). Otherwise Chrome lifts the text painted after it onto
  layers that lose their LCD rendering and it blinks, which no screenshot shows. A new one gets a
  `lifted()` check in the walkthrough, in the change that adds it, that it lifts nothing but
  itself, as the effect icon, the shimmer, the switch, the chevron, the Halls sweep and dot and the
  sound toggle have; design.md's Motion says how each moves.
- **Every panel is `Controls.panel/1`**: the card, the header band, the title (always an h2), the
  body. Options are `icon` (an emoji before the title), `collapsible` and a `header`
  slot. `id` names the PANEL, which its hook needs, and `class` styles it; `body_class` and every
  other attribute land on the BODY. A screen is addressed by
  `#screen`, which carries `PanelFocus` and the data attributes browser tests read. A panel takes a
  hook only when something in it moves, so the error page, with no LiveView, needs no JavaScript.
- **A collapse is the reader's, not the template's.** `aria-expanded` is the whole state: CSS hides
  a folded body off it, never a `hidden` attribute. The server draws the reader's kept fold
  (`collapsed`, from `MiniLineageWeb.Kept`); after that the attribute is the `Panel` hook's alone,
  `JS.ignore_attributes` keeping every patch off it. A click folds at once, keeps the fold and
  pushes `"fold"`, so a panel drawn again on this visit (the orders on coming back to the ground)
  is drawn as it was left. The header band is a BUTTON inside the h2, never a link (Space scrolls
  a link, and `PanelFocus` refuses to focus one), and it neither takes `PanelFocus`'s first focus
  nor gives it back, as a sort does. Opening by hand scrolls the panel into view; restoring or
  patching never moves the page. The chevron's transition waits for the `data-ready` the hook
  sets two frames in, which `JS.ignore_attributes` keeps off every patch, or the answer to the first
  fold strips it and the chevron snaps from then on. Every second-tier panel folds, on a desktop as on a phone; a first-tier one
  never does.
- **What the reader chooses is kept as `<kind>:<id>` in the `_mini_lineage_kept` cookie**:
  `panel:<id>` for a fold, `sound:effects` while sound is off, `table:<id>` for a remembered
  sort. `hooks/kept.js` (`recall`, `keep`, `keptCookie`, `refreshKept`) is the only code writing
  it, and `MiniLineageWeb.Kept` the only code reading it, for the first draw through the
  `live_session`'s session and again from the connect params, which beat the page's copy after a
  restart. It is the browser's, unsigned, so `Kept.read/1` drops whatever it cannot draw rather
  than raise. Its 400 days, Chrome's ceiling, restart on every visit. A new thing that remembers
  takes a kind, writes no storage code and is drawn from `Kept.read/1`; no choice goes in
  `localStorage`, which the server never sees.
- **Every button is `Controls.button/1`**, the only writer of `btn`. Without `patch` it is a
  `<button>`, because it does something; with `patch` it is an `<a>`, because it goes somewhere,
  never a link restyled as a button or the reverse. `variant={:secondary}` serves `<.select_action>`
  until something is picked (but for the town's Travel, which has nowhere to go back to), the hunt's Retreat, a fallen run's Play Again and the Halls' filters; `size={:sm}` and `active`
  (the one of a set already chosen) are the filters'. `variant={:link}` writes no `btn` but
  `link-button`, drawn by the link rule itself: an action standing where a link would, the orders'
  🧹 Reset to Default ending its row as "🎒 Open" ends the purse's, its emoji outside it as 🎒 is
  outside Open's anchor. It stays a `<button>` because it acts, and with nothing to put back it is
  disabled, muted and without its underline, never swapped for text: the swap rebuilt the row
  beside the SP figure, which blinked. A primary or danger button leads with an
  emoji; a secondary one has none of its own (`Return`), the filters' being their lineage's. `PanelFocus` gives a panel's first control the keyboard on arrival, so a destructive control
  is marked `data-no-autofocus`. The hunt's button reads "⚔️ Hunt" until a fight is held on this
  visit, then names where it goes next, a line of the ground's `Narratives.moves/1` other than the
  one shown, drawn by `GameLive` and never by the character's dice, which the bench seeds. A line
  runs to 18 characters, the room Retreat leaves it on one row at 360px.
- **Every dropdown is `Controls.select_action/1`**, because the dropdown and its button ARE the
  game's navigation: in a town it lists where you can go, at a trader or guild what you can do
  there. Only what makes no sense as a place to go from a town (the inventory, the character page) is
  a link. A place with several verbs keeps one list: each option names its `group` (drawn as an
  `<optgroup>`), and its `action` and `variant` are what the button says and looks like once it is
  picked, as the inventory's Equip, Unequip, Drink and, in red, Destroy. Every option reads "Pick"
  and its emoji and name, which the component writes: the verb is the button's, a price the table's,
  and a placeholder names where Return goes (`🚪 Traders`). A setting is no dropdown (see
  below). No `<select>` is written by hand but character creation's, three fields one Start button
  sends together and `phx-update="ignore"` keeps every patch off (`select_action_test.exs`). They all behave alike: the player's choice is touched by the player's
  own pick and the action it leads to, and by nothing else. Every action through `apply_action/3`,
  refused or not, clears `picked` and `picks`, so the list goes back to its start and the button to
  its default (a pick left standing bought the same pants twice). A push the player did not ask for
  (a regen tick, an aura fading, another tab) leaves an open list open, and four things shut one:
  - no option rendering `selected`: LiveView reads the list as changed on every patch and blurs it, so
    exactly one renders `selected`, the one the browser shows (the pick, else the placeholder, else
    the first option);
  - the `focus()` LiveView calls on the focused element after every patch, which on Windows shuts an
    open list; the `SelectAction` hook skips it;
  - a field named after a form property (`id`, `name`, `action`…): `form.id` returns the select, and
    the patch, keying on it, moves the form on every render. `select_action` refuses one;
  - options that move with a tick (HP, MP, an aura, the hour): the patch rewrites them. Build options
    only from what the player's own actions change.

  The walkthrough's dropdown tour holds every `select_action` in the source open across a tick,
  `traceRefocus` in `e2e/helpers.mjs` catching a focus or blur and an observer the rest, and fails on
  one it never reached, so a new page with a dropdown is added to the tour.
- **A setting is a `Controls.stepper/1` or a `Controls.switch/1`, never a dropdown**, which is for
  going somewhere or picking something. A stepper is a range over a few steps' indices (the server
  maps the index back, since the shares are uneven), filled to the one held, its value beside it;
  its form sends `phx-change` with `_target` naming the field. A switch is a `role="switch"` button,
  the name it switches and then a small track, green when on (gold is the skill name's), whose
  `aria-checked` is its state, never a `btn`, and `PanelFocus` treats it as it does a sort: it
  takes no first focus and gives none back to the panel's first control. A setting's success says
  nothing: its action returns `{:ok, nil}`, for which `apply_action/3` leaves the last flash
  standing, since the control shows it and on the ground the only alert is a new level's; a
  refusal still flashes. Its value jumps rather than counts: the player moved it.
- **Every alert is `Controls.alert/1`**, `kind` `:info`, `:success`, `:triumph` or `:danger`,
  anything else landing on the `div` (`alert_variants_test.exs`). Success is an action that got you
  something (a trade, a skill, a trip, a kill, HP mended); info one that only rearranged or set
  something, or a story. A new level is triumph, gold and shining, the flash's `levelled` drawn
  above it as `#levelled`, and on the ground the only alert, the fight being the page's. None is
  dismissed: what an action says, a refusal included, is its flash, dropped on the next arrival
  unless the action itself moved you there.
- **Every table is `Controls.data_table/1`, and every table sorts.** The container, header row and
  `<table>`, with the rows the caller's `<tbody>` and other attributes on the `<table>`. A sort is
  the server's, never the DOM's, which a patch would undo: a `:col` with `sort` is a header button,
  and `Screens.sortable/1` lists each table's keys and the default it opens on
  (`Screens.sort_of/2`). A click turns the sorted column round and starts any other ascending; there
  is no "off". The screen orders its rows with `Controls.sort_rows/3`, a name on the name and never
  its emoji, and its dropdown is built from the sorted rows, so the two agree. A trader, and the guild
  (Active, Passive), shows one table, each shelf its own `<tbody>` headed by a centred row (and a dropdown group) only when the
  page has two or more, and a sort reorders each shelf's rows without mixing them. `table_sort_test.exs` walks every page's tables, so a new
  table is added there. A sort header neither takes `PanelFocus`'s first focus nor gives it back to
  the dropdown. A table outlives a reload only with `remember` on the table AND in `sortable/1`,
  which `Kept.read/1` checks before reading a kept sort back; today the inventory's `items`.
- **A page shows what the fight works out, never the formula.** A skill's row reads the numbers
  `Hunt` uses for this character (`reuse_ms/2`, `cast_ms/2`, `heal_amount/2`, `blow_chance/1`), and a
  multiplier reads as Lineage II's data writes a buff: "+8% P. Def.", never "×1.08" or "√M. Atk.". A
  mastery reads the same way, its line's bonus as rules §25 writes it ("+14 P. Def.", "+13.4 P. Def.
  in a robe", "+8.5% P. Atk. and +2 P. Atk.", each bonus naming its stat), never a per-level sum or a rate. The canon's numbers were turned into these, the fight's
  own, in `1617e87`; a new skill's page is written the same way from the start.
- **What ends counts down where it is shown.** An effect with an end carries `remaining_ms`, a
  duration and never a deadline, so no two clocks are compared, and `EffectTimers` counts it down:
  legacy's pixel badge over the header icon, and on its Buffs & Debuffs row "+8% P. Def. for another
  1m 37s." (or, with no stat to change, "You rest again in 3s."). Each row hooks itself, since the rows sit straight in the panel body.
  Each also carries a `timer_key` naming that countdown, and the browser counts it from the first
  duration it is sent: a patch can repeat an old one, and a server clock can step (WSL2's does,
  3.6s every half minute), so a later duration never moves a timer already counting.
- **When something happened ages where it is shown**, through `Controls.stamp/1` and nothing else:
  "just now", "3m ago", "2h ago", "5d ago" (`form={:long}` for a sentence, "3 minutes ago"), and
  past a week its day, "17 Oct", the year only when it is not this one, with the whole instant in
  the tooltip, naming the zone ("17 Oct 2026, 3:10 pm EEST"). The `Stamp` hook ages each `<time>` from the age the server
  drew it at, `data-age-ms`, a duration as a countdown's is and counted from the first one it is
  sent, and repaints only as the label turns over. The day past the cap is the server's, written in
  the game's zone into `data-date`, so the browser never works out a zone. The Halls' Fallen
  is the only stamp today; an effect's time left is a countdown, never a stamp.
- **Every figure counts; only names and dates jump.** A number the player can watch change is a
  `<.figure>`, animated by `AnimatedValues` hooked once over whatever contains them. It writes
  `data-value` and the text from one value, and `format={:short}` sets both the short form and the
  `data-format` its frames count in. Adena counts short, and so does XP at the last level. Frames keep
  the tenth the settled value drops, so "2.0k" doesn't narrow to "2k" and jump the line. Animate a
  figure even where it can only move by one today: the count reads its distance from the delta, and
  a +1 tween is a 137ms delay, not a flicker. A row marked `data-stir` (the Halls') sweeps when any
  value it draws moves, a figure's `data-value` or a `<time>`'s `datetime`, and nothing else (the
  online dot, a medal another run took), as legacy's did; the sweep is the `data-stirred` attribute,
  which the row keeps off every patch with `JS.ignore_attributes`.
- **A bar is a figure against its cap.** `Controls.bar/1` draws track, fill and figures from `value`
  and `of`, with `aria-valuetext` on a `meter` (HP, MP) or a `progressbar` (XP), so width, text and
  speech agree. Without `of` it is the figure alone in a full track, as XP is at the last level.
  `wraps` names what going round is (the level, for XP), and `AnimatedValues` refills from empty
  rather than sliding back. `label` is drawn inside on the left. `format={:percent}` writes one figure,
  the floored whole percent of `of`, keyed `<key>-percent`. A bar leaves its class to the hook through
  `JS.ignore_attributes`, so a patch can't cut off a running sweep.
- **`class` and `style` render even when nil**, as `class="panel "` and `style=""`. Build them before
  the tag (`classes/1` in `Controls`) or spread a keyword list.

### Prose and markup

- **The game's prose joins its clauses rather than splitting them with an em dash**: a dash in a
  sentence a player reads becomes `because`, `and` or `nor`. Comments and docs are exempt.
- **Adena always comes with its coin and its gold.** An amount in a message is `Format.adena/1`
  (`🪙 N Adena` in `.adena`), and a table cell or figure is `.adena` led by 🪙.
- **A stat is named as Lineage II's client names it, through `Format.stat/1` and nowhere else**:
  P. Atk., M. Atk., P. Def., M. Def., Atk. Spd., Casting Spd., Speed, Accuracy, Evasion, Critical,
  and ours where it has none or several (M. Critical, Block, Shield P. Def., HP Recovery, MP
  Recovery, Max MP), each a departure in `docs/canon/README.md`. A stat ending a sentence lends it
  its full stop (`Format.stop/1`): "+16 M. Def.". `rules.md` spells them the same; the rest of
  `docs/canon/` keeps its sources' spelling.
- **A bonus leads its stat; an item's own number follows it.** "+8% P. Def.", "-3 Accuracy", "+38 Max MP",
  but "P. Atk. 6". A rate carries its % wherever it is written ("Critical 8%", "Block 20%").
- **A level is named as one, "Level 5", word and number together in `.level`**, a monster's
  ("a Gremlin, Level 1") as much as the character's ("until Level 5"). A level no number names
  ("the next level") is a common noun and stays lowercase and uncoloured.
- **What a blow takes is damage**, as the client's own "You hit for $s1 damage." counts it: in the
  fight log every figure a blow, spell or tick deals is `N damage` inside its span, as a mend is
  `N HP` inside its own, and a list writes the word once, after the last ("10 and 9 damage").
- **HP is mended, never healed**, by a skill, a potion, rest or an order, and what is mended is
  `.regen` with its HP inside the span. A name keeps its word (Self Heal, Healing Potion), and so
  does the code's `heal` kind. `stat_names_test.exs` renders every set's character, guild and
  inventory pages and every item's line against the stat names, a bonus before its stat, a rate's
  % and HP mended.
- **A time on a row is short**, as `Format.remaining/1` writes it, in its two largest units ("3h
  12m", "1m 37s", "2m", "3s") where a badge shows one ("3h", "2m", "3"), with the
  fight's tenths where it has them ("Cast 5.3s, reuse 10.4s."). Narrative prose keeps its words.
- **An effect's title is its name, then what bounds it, then what it changes in brackets**:
  "Night until dawn at 6:00 am UTC (-3 Accuracy)", "Shadow Sense (+3 Accuracy)", "Resting". Only
  `Snapshot.aura_view/1` writes one, so a new effect, a new bound or a new kind of change goes
  through it and keeps the order; `night_test.exs` holds it.
- **A place keeps its role; its keeper's name is in what is said there.** The Gatekeeper is
  "Gatekeeper" in the dropdown and the header, and by its town's keeper's name (Roxxy at Talking
  Island) in the intro and the flashes.
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
- **The server rates and the time zone are the rules a deployment may change** (rules §22, §15). `config.exs` holds
  retail's ×1 and every env file, CI's jobs included, the private ×5, ×5 and ×20 the game is
  balanced at; `rules_test.exs` holds `config.exs` and the two `.example` files to the document,
  and nothing checks CI's. `runtime.exs` reads them in every
  environment, so the suites and the bench play `.env.test`'s, and a reading names its rates.
  `Hunt` takes a rate as an argument and `Actions` passes `Rules.rate/1`, so a test states the rate
  it works at. The `balance-study` skill checks a reading was taken at the private rates. The zone
  is UTC everywhere but where a server sets `TIME_ZONE` (the owner's dev `.env` sets
  Europe/Bucharest; `.env.example` carries it commented, and no suite, CI job or example file sets
  it), `runtime.exs` refuses a zone `Tz` does not know, and `rules_test.exs` holds this to §15. It
  moves only which hours are night and how a time is written, never what is stored. The game shows
  its clock where a player meets it: the banner's, in the subtitle's old place (`GameLive` redraws
  it at each minute's turn, so only the server names the zone), and the 🌙 Night aura's "until
  dawn at 6:00 am UTC", counted down like any effect with an end.

### Comments

One to three lines, why and not what: a constraint, a trap, a decision that looks wrong until you
know why. Never narrate the line, restate the identifier, or tell how the bug was found. Needing more
than three lines means the knowledge belongs in this file. Moduledocs may run to a short paragraph. A
comment citing a measurement expires when what it was measured against moves. A longer block met in
a function being rewritten is compressed with it, never left for later.

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
