This is Mini-Lineage Remastered: a text-based RPG in Elixir, Phoenix LiveView and OTP.

## This project, specifically

The generic Phoenix guidance below is worth reading, but where it disagrees with this list, this
list wins — several generator defaults do not exist here.

- **The live game is the base layer and nothing more.** Character creation, the race's starting
  village with the status sidebar, the Chronicles of Ancestry and the error page. Everything the
  game was before that is in `legacy/`, which is read and never run; see the rule below.
- **There is no `core_components.ex`.** It was deleted as dead code, so there is no `<.icon>`, no
  `<.input>`, and no `<.flash_group>`. Every control is hand-written HEEx in
  `lib/mini_lineage_web/components/`. Ignore any advice below that reaches for those.
- **There is no HTTP client** — no `Req`, no `:httpoison`. The game calls nothing outward.
- **There is no authentication**, so no `current_scope`, no `live_session` scoping, no user table.
  A browser is tied to a character by a signed session cookie and nothing else.
- **There are no LiveView streams.** One character's state is one assign.
- **There are no colocated hooks.** `app.js` imports its hooks from `assets/js/hooks.js` and nothing
  else, so a `ColocatedHook` would compile and never run. A hook goes in a file of its own under
  `assets/js/hooks/` and is listed in `hooks.js`, which holds nothing but that list and what
  `app.js` imports through it. The hooks are `AnimatedValues`, `Panel`, `PanelFocus` and
  `SoundToggle` (over the synth in `soundfx.js`); `kept.js` is storage.
- **Two sounds, and only two.** The new-game fanfare is the flash's `sound`, which `GameLive` pushes
  as `play-sound` for `app.js` to play, so nothing in the DOM can replay it on a reload. The
  toggle's chime is the browser's own. A sound is a list of notes in `soundfx.js`, no assets.
- The database is **PostgreSQL via Postgrex**. Character state is a single `jsonb` document in
  `characters`, the only table.
- One `GenServer` per character under a `DynamicSupervisor` + `Registry`. Anything that mutates a
  character goes through its process, never straight to the database.
- `<Layouts.app>` does exist and every LiveView template starts with it.
- **One LiveView, one dispatcher.** `GameLive` holds no game state and routes everything through
  `Access.pin_screen/2`. `Screens.screen/1` picks the page — start, town, races, error — and all of
  them live in `Screens` until one is big enough to need a module of its own. Anything a page
  reaches for but does not own (`<.panel>`, `<.data_table>`, `<.button>`, `<.alert>` and
  `<.flash_alert>` built on it, `<.back_link>`, `<.figure>` and `<.bar>`, `<.fault>`) is in
  `Controls`; `Layouts` holds the shell's `head`, `site_header`, sidebar and `footer`, which
  `ErrorHTML` draws too. The sidebar — the vitals, Stats and the Inventory — is one `.side` column
  beside the main one, at its own fixed width, and one breakpoint stacks it.
- **The town's 🚪 Quit button is temporary.** It deletes the character so one browser can try every
  race and path, and exists only in a debug build: `GameLive` neither draws nor answers it in a
  release, and `quit_test.exs` holds that. It goes when there is a real way to start over.

### Working here

- **`.env.test` decides the browser suites' port, never `.env`.** `mix e2e` runs in `:dev`, where
  `.env` would hand it `PORT=4000` and it would sit waiting on the development server. It gets away
  with this only because a Mix task does not start the application; adding `app.start` would break
  it silently.
- **Node is `.nvmrc`'s and nowhere else.** It runs only Playwright. CI reads it through
  `node-version-file`, `env.sh` selects it through nvm, and `mix e2e` refuses any other, so a
  version is changed in that one file and never written into the workflow.
- **A release is checked with `e2e/release.sh`, which is what CI's publish job runs before it
  pushes.** It builds the image as CI does (`buildx --load`, `APP_VERSION` the short sha), reads the
  stamp back out, brings up the real `docker-compose.yml` against an empty Postgres 18 through an
  override that swaps only the image and adds the database, and waits for compose's healthcheck and
  the boot migration. Then the socket's origin check both ways and one character in Chromium. Run it for
  anything that reaches the image: the Dockerfile, compose, `config/prod.exs` or `runtime.exs`, a
  migration, the release steps. It hands compose an env file of its own, because compose reads
  `./.env` for interpolation and that names the real database. If `docker`, `docker buildx` or
  `docker compose` is missing, install them rather than skipping the check: the rootless Engine
  needs no root (`curl -fsSL https://get.docker.com/rootless -o rootless.sh`, read it, `sh` it), and
  buildx and compose are release binaries from their GitHub repos dropped into
  `~/.docker/cli-plugins/` after checking the published checksums. README's Docker section has the
  steps.
- **Database tests cannot be `async: true`.** A character lives in a GenServer started by a
  `DynamicSupervisor`, so the sandbox cannot trace ownership from the test process to it. Shared
  mode bridges that, and shared mode means serial. This is our architecture, not the driver — it
  was just as true on MySQL.
- **Nor can a test that changes global state** — Application env, an OS variable. Another async
  module reads it mid-flip; `error_html_test` turns the debug build off and deletes APP_VERSION.
- **Nor can a test that claims a registered name.** The name is global, so every async module
  that creates a character would post into the test's mailbox. A test that stood in for a
  collector this way once failed about one seed in eight.
- Migrations commit their DDL implicitly, which ends the sandbox transaction. That is why
  `release_test` checks configuration rather than running one.
- `mix precommit` before you call anything done, and `mix e2e` for anything the browser renders —
  a screen, a hook, a selector, a rule that changes what an element *is*. ExUnit's coverage understates
  the web layer because the browser suites are not instrumented, not because it is untested.
  A change that only moves colour values is the exception: no suite can fail on a hex, and running
  them there buys nothing but minutes and their own flakes. `mix precommit`, then look at it.
- **A browser check hands Playwright a function, never a string.** The CSP refuses `eval`, so
  `waitForFunction("…")` throws at once, and behind a `.catch` it reads as a wait that returned.
- Show a new test failing before you claim it passes. Break the thing it covers, watch it go red,
  put it back. A test written after the fix and never seen to fail is decoration. Put it back with
  `git checkout` or `touch` it: a copy restored from a backup is older than the build, and Mix
  keeps compiling the broken one, so the next mutation fails for the last one's reason.
- **A property states what holds for every input; the fixtures stay the contract with JavaScript.**
  StreamData is `:test` only, so `.formatter.exs` spells out its macros, since `import_deps` fails
  in `:dev`. A counterexample a property finds in a twinned formatter becomes a row in its fixture.
  Weight a generator toward the boundary: a uniform draw rarely lands on one. Dice are a generated
  list cycled through `Rng.put_source/1`, which states a rule for EVERY roll rather than asserting
  one, and they are integers scaled into `[0, 1)`, never `float/1`: its bounded generation grows
  with the size, and 3,000 runs took over a minute.
- **The dev tools are dev only, and none of them may loosen the CSP.** LiveDebugger runs at
  `:4007` with `browser_features?: false`, so it injects no script; its DevTools panel reads the
  config tag `Layouts.head` renders and nothing else. Its assigns view shows `session_id`, which is
  a credential, so never paste it anywhere. Tidewave is plugged in only on `/tidewave/*`, because
  on any response it touches it adds `'unsafe-eval'` and drops `frame-ancestors`; `.mcp.json`
  points Claude Code at it. Its `project_eval` is for reading: a write goes through `Characters`,
  never `Repo`.
- **Never compile into `_build/dev` while the dev server is up.** A `mix` command in `:dev` and the
  server's code reloader writing and loading the same beams at once gave "corrupt file header" and
  crashed a character process mid-game. Ask the running app through Tidewave's
  `project_eval`, give a script its own `MIX_BUILD_PATH`, or run it in `:test`.
- **A question about the running app goes to the running app.** Through Tidewave: `project_eval`
  for state (`:sys.get_state` on a character, timing a call with `:timer.tc`), `execute_sql_query`
  for `EXPLAIN (ANALYZE, BUFFERS)` on the statement Ecto actually sent, captured with a `:telemetry`
  handler on `[:mini_lineage, :repo, :query]`, and `get_logs` for what a request did. The plan, not
  the code, is what finds a slow query.
  A rehearsal at scale goes inside `Repo.transaction` with `Repo.rollback`, and `VACUUM FULL`
  afterwards, because rolled-back rows still bloat the indexes and change the planner's sums.
- **A new component, hook or shared control is written into this file in the change that adds
  it.** What is described here is what the next change reaches for; one nobody wrote down gets
  built a second time beside it, slightly different. Before writing a control, look here and in
  `Controls` for the one that already does it, and extend that one with an option instead.

### Rules that are not negotiable

Each of these is here because it was got wrong once.

**The base layer is `docs/rules.md`, and nothing else.** It is ours, written in our own words: the
eight starting sets and the village each race starts in, the six attributes, every stat and
formula, resting, levels and the base outcomes. A number may be taken from L2 when a rule is
written, whole and never rescaled beside numbers that were not, but once written the document is
the only authority and nothing outside it is consulted. The code matches it rule for rule — `Rules` holds its tables, `Formulas` its
formulas in its order — and `rules_test.exs` reads the tables back out of the document and works
every example again, so a change to one is a change to both. A new system (classes, items,
fighting, the world) starts as an entry in `docs/roadmap.md` and builds on the rules rather than
quietly changing them.

`Player.stats/1` runs the rules in order from the set a run started as and its level. A new
character has no Adena and no items, in every environment.

**`legacy/` is read, never run.** It is the game as of `da4e37c`: the shops, the Battleground,
the record and its Chronicle, the Halls, the Tome, class transfers, dyes, timed buffs, every
sound but the two above, and the cheat. Nothing there is compiled, formatted, tested or served, and nothing outside it may
import, alias or route to it. A system rebuilt from it is rebuilt on the base layer, in the live
tree, with its rules and tests written fresh; its old code and old `AGENTS.md` are a reference for
how it once looked and what was learned, not something to copy back whole. Update nothing in it.

**Never assert on a roll of the dice.** Not in the browser suites, not in ExUnit. Pin the source
with `Rng.put_source/1`, or arrange the state so that no roll changes the answer. A pinned source
holds only in the process that pinned it: a character's GenServer rolls its own dice, so pin them
inside it, from a function handed to `Characters.mutate/2`. An assertion that holds for most rolls passes
for months and fails in CI once.

A randomly drawn *string* is the same trap wearing a disguise. The welcome is drawn from a pool,
and one of its lines names "the world of Aden" — so a browser check that the City of Aden is gone
failed on the roll until it asked for the whole phrase. Where a test reads a drawn line, fix the
draw first or match only what every draw shares; that it came from the pool at all is a separate
test's job, against the struct rather than the page.

**A formatter with a client-side twin is held to a table.** `Format.short` and `shortFigure` in
`hooks/animated-values.js` are duplicated on purpose: the count-up animation formats its own frames,
and without a client-side copy the number would change format mid-count. Both read
`test/fixtures/short_format.json`, from `format_test.exs` on the Elixir side and `walkthrough.mjs`
on the JavaScript one. Change either implementation, change the table, and both tests will tell
you. Anything else the two languages both format wants the same treatment before it gets a second
copy.

**Mutable working state is a document; anything sorted on is a column.** `characters` is owned by
a process and only ever read whole, so it is one `jsonb` blob. When something comes to rank or
filter on a field of it, that field becomes a GENERATED column over the document, never written by
application code, so it cannot drift from it; under PG18 write `STORED` explicitly or you get a
VIRTUAL column that cannot be indexed. Anything that grows with play — a battle history, an
inventory, a mail box — gets its own table. Put it in the document and every save rewrites all of
it, buffering or not.

**A character has two ids and they must never be confused.** `id` is public and is the only one a
page may ever show or link; `session_id` is the cookie and is a credential. A public id that is also
a session lets anyone play as somebody else by pasting their link into a cookie. Anything that lists
characters selects into plain maps rather than `%Record{}` for exactly this reason — a struct
carries a `session_id` key.

The session names the BROWSER, not the run, so it outlives the run's process and every tab.

**Writes follow the player, not the clock.** What the player did is written before they are told it
worked, and today that is creating the character. The passage of time — resting — is buffered and
rides along with the next write, the 60-second backstop, or `terminate/2`. The decision is derived
from the struct in `Characters.Server` (anything outside `@buffered` changed), never declared at a
call site, because a call site can forget.

**The URL is where you are.** Start and the starting town are one browser's two states and share
`/`; `Access.pin_screen/2` decides which. Somewhere you can stand that is not your own village — a
shop, a hunting ground, a record — gets a URL of its own when it is built. A state that happens to
you does not.

**Do not widen a guard to make something work.** `Access.pin_screen/2`'s clauses, the check in
`e2e/reset.sh` that refuses the database `.env` names, `Actions.start/4`'s preconditions: each one
is the boundary, and there is a test asserting what it still refuses. If a guard is in the way, the
thing you are building is probably wrong.

**What the player can see is what heals them.** The 🌿 aura and the regeneration tick are one
condition, not two copies of it: `Player.regenerate/1` heals HP and MP by whatever rates
`Player.auras/1` puts on the aura, one for each bar still short, so an icon with no healing behind
it — or healing with no icon — cannot happen. The tick is the 3 seconds of rules §11, so a rate is
what one tick restores.

**The cookie is only legible to the secret that signed it.** dev and prod read the same `.env`,
so `config/runtime.exs` hands both the same `SECRET_KEY_BASE` — otherwise switching between them
mints a new session and the character looks lost while sitting in the table untouched. Dev falls
back to the secret committed in `config/dev.exs`, so a clone with no `.env` still boots.

**An anchor wraps its text and nothing else.** A newline inside one renders as a space, and the
underline covers it — which is how a link once came to underline the gap before a medal and the
footer the gap after the sha. Where the attributes force the tag open across lines, keep the
content flush against `>` and `</`; where the label is long, name it above the `~H` rather than
letting the formatter break it inside the tag. Buttons are exempt, being padded boxes.

**Declare a property only where the element would not otherwise have it.** Either it does not
inherit — form controls and buttons take no font or colour from `body`, which is measurable and was
— or it differs from what it does. Restating the inherited value gives `body` a second place to be
changed and no second effect, so `.data-table td` and `th`, `h2` and `.stat-value` say nothing
about colour while `.stat-label` does. If a container is ever made secondary, the children that must
stay primary will need to say so then; adding it in anticipation is how the two drift apart.

**A panel header's contents are placed by the band, never by themselves.** These are capitals, and
a font's em box carries descender room they never use, so centred they sit high — `.panel-header`
is padded 9 over 7 to answer that, and every child moves with it. It used to be a `margin-top` on
the title and half of one on the effects strip, which is why the chevron could not line up with the
words: three things were being centred by three different rules. Line-height cannot do this job —
it is symmetric by definition, and the correction is not.

**Size is hierarchy, never container.** 13px is anything you read — prose, an alert, a table cell, a
sidebar value — because the same thing set a step smaller in one place reads as a different kind of
thing. 12px is a control, 11px a label — a column's, a field's — set by one rule in `base.css` at
weight 600 and 0.1em in capitals, each in its own colour and place, or the footer. The figures
inside the HP, MP and XP bars are the one exception, at 10px: an 18px bar has no room for more. A
field label's 1px `margin-top` is optical, not a bug: centring works on boxes, a box keeps descender
room capitals never use, and the one property that centres by letters, `text-box-trim`, is missing
from Firefox. The sidebar is 210px; widen it before shrinking a value, and never without asking.
The headings run h1 for the screen the panel names, h2 for a section inside it, h3 below that; the
sidebar's panel titles stay spans so a page has one h1. Nothing skips a level.

**Weight answers "which of these matters?", so a table never needs it.** Tabular figures are on
`body`, not on a list of classes: the game is arithmetic, and a column of numbers wants to line up
while an animating one wants to stay still — the HP counter runs inside a paragraph, and
proportional digits reflow the line on every frame. The weight is scoped to `p` and `li`, because inside a sentence a number has nothing
but hue to set it apart, while a column has answered that question already and weighting every
cell of one only makes the table heavier. Measured before it was put back: the weapon shop read 93%
bold, the character page 24%. The list is one `:is(p, li) :is(…)` rather than two classes spelled
out per selector, so adding a name to the vocabulary is one edit and not three. Only Inter 400, 500
and 600 are loaded; asking for 700 gets a fake.

**A table has no minimum width, and gives no column the width; its rows decide.** Whatever they
leave over is shared among every column in proportion to its content, so the gaps between figures
grow only where there is room. A fixed gap of 24px took it from the name instead, and the armour
shop's longest name wrapped on desktop, where that table has about a pixel to spare. A figure never
wraps; a name may; on a phone a column's label may take two lines, never stranding a unit, so a
label carrying one binds it with `&nbsp;`, an entity rendered with `raw/1`, since the label is
interpolated and would otherwise print it literally. A `min-width` had held the shops at 420px,
which on a phone put the cost behind a sideways scroll. The columns stack below 640px, before the
sidebar can squeeze a table narrower than a phone would give it. A wide table may still scroll on a
phone, provided what matters most is on the left. Check a table
change by counting the lines in every cell at every width, not by whether it scrolls: a row's cells
share one height, so a wrapped name makes the whole row look taller.

**A class per thing the game names, never per colour it is drawn in.** `.hp`, `.mp` and `.adena` are
written apart even where two of them resolve to one token today, because the moment one should
move the others must not come with it: the group is an observation about today, the name is the
thing. A class named after its colour cannot say which of the things wearing it you meant — `.hp`
once carried health, Max HP, Physical Attack and deaths, and no one of them could be retuned.

These are the game's vocabulary and they are filed under **Values** in `base.css`. What is not a
value lives above them under **Utilities**: `.muted` is what is not a value standing where one would
be — the `&laquo;` of a back link — and takes no weight. `.build-development` and `.build-testing`
are there too: which build serves the page is something the PAGE knows, not something a player
reads. A value's class goes where the thing is named in a sentence, figure or no figure, and never
on a label naming a field or a column, which stays a label. A value is a classed `<span>`, never a
`<strong>`. Every text colour is a token; adding a class means putting it in a group, never
inventing a hex. `legacy/AGENTS.md` has the whole vocabulary the old game used, to reach for when a
system brings one of its things back.

**A line keeps its pronouns open until somebody reads it.** Who a line is told TO is not known
until a page opens, so every narrative pool carries `{they} {them} {object} {their}` and
nothing second-person, `Format.fill_template` leaves them alone at build time because
they are not in the data map, and `Narrative.voiced/2` closes them at render: `true` for the run's
own alert (`Narrative.alert/1`), `false` for anybody else. Verb agreement is free — they/them takes
the same forms as you, which is the whole reason the game picked it — but REFERENTS are not, so a
line naming two people has to keep them apart by construction. The game records no gender.

**`Access.pin_screen/2` gates what may be DONE, never what may be read.** `races` and `error` carry
no action, so the first clause lets every state reach them and the rest only ever decides about
screens that can be acted on: a character is in its town, and a visitor is at game start. It had
been three overlapping allowlists once, which is how a run was kept from reading pages it had every
right to.

**The game has no catch-all route, and that is deliberate.** A glob answering every unrecognised
path resolves it to Town and rewrites the address, which is a soft 404: the reader is told nothing,
the address they typed is discarded, and a static path that reaches the router — a mistyped
stylesheet — is answered with HTML the browser then fails to parse as CSS, so the real fault is
invisible. Phoenix raises for what it does not route and `ErrorHTML` draws it in the game's own
shell. `Access.pin_screen/2` redirects are a different thing and stay: moving somebody because they are
NOT ALLOWED somewhere is not the same as moving them because the somewhere does not exist.

**What a build may say about a fault depends on the build, not on what it knows.** The error page
shows the WHOLE thing in a debug build — `Exception.format/3` on the kind, reason and stack Phoenix
hands the view — because the alternative is reading "500 Internal Server Error" on the page and then
going to find the terminal it actually happened in. A release shows none of it, whatever it was
handed: a trace names modules, line numbers and arguments, and a player is not the audience for any
of them. `Version.debug_build?/0` is the gate, and it is deliberately NOT tied to `release?/1` — an
image built without APP_VERSION could not tell it was a release, and served traces to players. A 404
is not a fault and gets no trace either way, or the real ones drown in mistyped URLs. Both error
pages draw the trace and the way out through `<.fault>`: drawn apart, the in-game screen had lost
the rule over its way back that the Phoenix page kept.

**If a character has a standard named entity, write the entity.** `&amp;` `&copy;` `&ndash;`
`&bull;`, and `&nbsp;` `&mdash;` `&hellip;` if ever needed. Everything else is written as it is:
ASCII prose, and every emoji in the game, none of which has a name to spell. The rule is worth
having precisely because it asks nothing of whoever applies it — no judgement about which glyphs
are confusable or which are legible enough to leave bare, both of which are arguments rather than
rules, and both of which had already produced a footer with `&copy;` three lines from a literal
`•`. A named entity exists or it does not, and that decides it.

**The game's own prose joins its clauses; it does not hold them apart with a dash.** An em dash in
a sentence a PLAYER reads becomes `because`, `and` or `nor`. This is about the game's voice and
not the codebase's — every `@moduledoc` and comment here is full of em dashes, deliberately, and
they are none of a player's business.

**A link is underlined, never gold.** Gold is what a run is worth, and a name once sat in the same
colour as the level and the wealth beside it, with nothing saying which could be clicked. A
link is the colour of the words around it, on a 1px underline of the same colour 2px below it, and
on hover both darken to `--text-link`. The line is never given a colour of its own: it is
`currentColor`, so changing the word changes both. `--text-link` is not a hue but a darkening,
`currentColor` mixed 77% with black and resolved where `var()` is used, so one rule serves a link in
prose and a link in an alert, which had once been painted prose-white in a red sentence. Black and not `transparent`: a fade is lighter on a lighter ground, and the sidebar's
hover missed `--text-secondary` where the panel's hit it. 77% of `--text-primary` is
`--text-secondary` to one unit of blue. Its rule never says `:link` or `:visited`: a rule matched
through `:visited` may set colours and nothing else, so every link a player had opened would lose
its underline. The banner opts out with `text-decoration: none`; the footer's commit turns gold
on hover, and its line with it. That fade is base.css's, a transition on `color` alone, which
carries the line because the line is the word's.

**A token is named for its ROLE, never its family: `--<role>-<name>`.** `--text-`, `--bg-`,
`--border-`, `--wash-`, `--bar-`, `--glow-`, `--shadow-`, `--focus-`. Type `color:` and there is
one prefix to reach for and one word order to remember, and a family stays honest across roles —
HP is `--text-hp` in a sentence and `--bar-hp` in a meter. That pair used to be `--text-hp` and
`--hp-color`, two shades of one family disagreeing about word order, with `--success` the colour
`.heal` wore and `--success-text` the one it did not. Gold is the single exception, because it is
a hue rather than a role: the accent is deliberately text, border, ground and glow at once, and
prefixing it would mean four tokens holding one colour.

The two sets of text colour are named apart: a value for the thing it marks (`--text-hp`,
`--text-heal`, `--text-tally`), an alert voice for its kind (`--text-danger`, `--text-info`). Green had been both, so the voice got `-bright` bolted on.

Adding one means checking it, not eyeballing it: 4.5:1 on `--bg-panel`, inside the palette's own
saturation and lightness, and clear of every other by eye in Lab. Maximising distance alone returns
neon — that search has been run twice and been wrong twice.

**A colour JavaScript needs is READ from its token, never copied beside it.** The loading bar's
stops are the value colours in hue order, and they were spelled out in `app.js` — where six of the
seven quietly went stale behind a repaint of the palette, because nothing in a stylesheet can fail
when a hex in a script stops matching it. `getComputedStyle(document.documentElement)` answers with
whatever the tokens say today; `app.js` is deferred, so the stylesheet has already applied.

**Judge colour in CIELCh, never in HSL.** HSL saturation is a coordinate, not a quantity: 27% on a
panel at 8% lightness looks neutral and 27% on a button at 40% looks blue, which is why the
controls had to sit well under the surfaces' number to read as the same slate. Lightness is `L*`,
colourfulness is chroma, and both compare across hues where H, S and L do not.

**Peers share a lightness. They do not share a chroma.** The colours that land in one sentence —
`--text-hp`, `--text-critical`, `--text-heal`, `--text-tally`, `--text-defense`, `--text-xp` —
are all `L* 58` and so read at 4.9 on the panel, which is what makes them peers; they had ranged `L*
57` to `66` and the tally whispered. Equalising their chroma is the trap, and it was fallen into
once: teal tops out near 39 at any lightness in sRGB, so a shared chroma *is* 39 and the whole set
goes pale to meet the one hue that cannot keep up. True equality across those six peaks at 45, below
where the palette already sat. Each runs to its own ceiling instead, capped at 72.

**A panel is held off the page by lightness, and the number is 7.6 `L*`.** The blue palette held it
with 8.6 `L*` *and* 13.5 chroma at once. Taking the chroma out was right; what nobody noticed is
that the gap had also closed to 3.1 from both ends, leaving the panels held apart by their border
and their shadow alone, which is tiring to read against. If the surfaces are ever restyled this gap
is the thing to protect — it is the whole of the separation now.

**A surface nested in another lifts off it, never sinks into it.** A table whose header band and
container edge were darker than the panel read as a hole in it. `--panel-lift`, `--table-lift` and
`--row-lift` are white at three strengths rather than hexes, so one lift works over any ground.

**A mechanical colour transform runs in a single pass.** Desaturating the chrome, `#322b3b` was both
an input and an output — the secondary button's hover top, and also what the primary's rest bottom
desaturates to — so a sequential find-and-replace hits it twice. Build the whole map first, then
substitute once.

**A comment citing a measurement expires when the thing it was measured against moves.** The bar
glows' comment claimed 4.55 and 4.53 on the panel; the panel then moved twice under it and it went
quietly false. Moving a ground means re-measuring everything any comment asserts about it.

**Every figure counts; only names and dates jump.** A number the player can watch change is a
`<.figure>`, animated by `AnimatedValues`, whose hook sits once over whatever contains them. The
component writes `data-value` and the text from one value, and `format={:short}` both the short form
and the `data-format` that counts in it, so the two cannot be written apart. Only names and
dates jump, having nothing to count through. Adena and the XP bar count in the short form, since a
level's EXP runs to 4.2 billion and the bar is 210px; the frames keep the tenth that the settled
value drops, because "2.0k" written "2k" is two characters narrower and the line jumps left and
right across every round thousand.

Animate a figure even where it can only move by one today. Measured: a tween of +1 renders the old
number for 137ms and then the new one — a delay, not a flicker — and forty at once hold a median
frame of 16.7ms, which is 60fps with nothing lost. A count reads its distance from the delta, never
from a guess about how far a value can jump, so a turn that one day gives two fights or experience
enough for two levels needs no markup change. The alternative is deciding per figure how far it can
move and being wrong later. The level once came off a board on that wrong guess and went back on.

**A bar is a figure against its cap.** `Controls.bar/1` draws the track, the fill and the figures
from `value` and `of`, and tells a screen reader the same through `aria-valuetext` on a `meter` for
HP and MP and a `progressbar` for XP, so the width, the text and what is heard cannot disagree. Without
`of` it is the figure alone in a full track, which is what XP becomes at the last level: there is no
next one to fill toward, so the total is the figure. `wraps` names what going round looks like, the
level for XP, and `AnimatedValues` refills a bar from empty when it changes instead of sliding it
backwards.

**A screen that shows somebody's figures is pushed to, not polled.** `"character:#{session}"` is
the browser's own topic and carries what only its owner may act on — its key is a secret, so
nobody can watch anybody else. A second tab on the same browser follows along through it. A topic
another reader may follow (a public record, a board) is keyed by the PUBLIC id, and followed only on
the screen that draws it.

A push must not announce what cannot yet be read. `Server.run/3` broadcasts AFTER it persists,
because a reader answering a push by reading the database finds nothing otherwise. It costs about
1.2ms before a push lands and is worth it.

**A browser suite tests the game, not its CSS.** A 600ms sweep across the HP bar was once checked in
the walkthrough and failed about one run in three, taking the whole suite with it. What triggers a
sweep is what matters and is checked instead. A bar leaves its class to the hook through
`JS.ignore_attributes`, so a patch cannot take a running sweep with it.

**A visitor is never written.** A browser that has not chosen a lineage lives in its process and
nothing else: the tick skips a run that has not started and nothing else can change one, so
nothing marks it dirty and nothing persists it. That is why the retirement only ever clears
sessions and deletes nothing, and why `characters` has no row without a race. `visitor_test.exs`
holds it.

**The registry can name a process that has just stopped.** `Characters.call/3` looks a character up
in the registry directly, which is what keeps every read and write off the `DynamicSupervisor` —
starting a character runs two queries inside the supervisor's own loop, and everyone else would
queue behind them. The price is that a lookup reads ETS and can see an entry whose `DOWN` is still
sitting in the registry's mailbox, so the RETRY goes through the supervisor: registering a name is
handled by the registry itself, behind that DOWN, and by then the stale entry has gone.

**A figure on a page is animated, so a browser suite reads `data-value` and never the text.** A
figure counts up to its new number over 600ms, so `textContent` mid-tween is a frame: a wait for
"has this figure moved" once returned on the first one — 3, where the value was 62 — and every
check downstream compared the wrong moment. The attribute is what the server wrote; the text is
what the animation is showing.

**Every panel in the game is one component.** `Controls.panel/1` draws the card — the header band,
the title, the body — and the differences are options: `heading` for the screen's own h1, and only
that one, `collapsible` and `collapsed` for a header that folds. `id` names the PANEL, which is what its hook needs; `body_id` and everything else handed to it
land on the BODY, which is what a screen is addressed by — `#screen`, its `PanelFocus` hook and the
data attributes a browser test reads. A panel takes a hook only when something about it moves, so
the error page, which has no LiveView behind it, renders one that cannot ask for JavaScript.

**A collapse is the reader's, not the template's.** `aria-expanded` is rendered once for the
opening state and belongs to the `Panel` hook after that, re-applied on every `updated/0`. It is the
WHOLE state: the stylesheet hides a folded body off it, never a `hidden` attribute, so a layout with
room for a panel can keep it open before any script runs, and says so to the hook with
`--folds: 0`, where the header is disabled. What the reader last did is kept under `panel:<id>` in
`localStorage` and beats the template on the next mount.

The whole header band is the control, and it is a BUTTON. It goes nowhere, and a link would say it
did: Space activates a button and scrolls a link, which is the same reason `PanelFocus` refuses to
focus one. The chevron turns off `aria-expanded`. The gold line belongs to the BODY as a
`border-top`, never to the header as a `border-bottom`: a shut panel then draws no line closing off
what is not there.

Opening by hand brings the panel into view. Only by hand — a panel restored open from storage, or
patched while open, was never asked to move the page. Nor may it animate into a restored state: the
chevron's transition is gated on a `data-ready` the hook sets two frames in, or every refresh spins
it through a state the reader never left. Beside the main panel a side panel does not fold, unless
it is marked `.folds`: the Inventory folds only on a phone and opens unfolded, while Stats folds at
every width and opens folded. The phone's rules repeat the desktop's `:not(.folds)` selectors, so
they win by order; written plainly, the desktop's extra class outranked them and nothing folded.

**Every button in the game is one component, and the element is what it does.** `Controls.button/1`
is the only thing that writes `btn`, and today it is always a `<button>`, because it does something.
One that goes somewhere is an `<a>`, so a reader can open it in a new tab: it comes back as a
`patch` option when a screen first needs one, and never as a link restyled into a button or the
reverse. That is why base.css's link rule is `a:where(:not(.btn))`, an element's specificity:
`a:link` outranked one class, and painted a button-link in link colours. The focus ring is
`currentColor`, so a look added later rings in its own colour without a rule of its own. A variant
(secondary, danger, small) comes back the same way, with its CSS from `legacy/`.

`PanelFocus` gives the panel's first control the keyboard on arrival, so a control that destroys
something is marked `data-no-autofocus`, or one stray Enter acts on it. The Quit button is.

**Every alert in the game is one component, and none is dismissed.** `Controls.alert/1` is the only
thing that writes `alert`: `kind` is `:info` or `:danger`, the two the game raises, and anything
else handed to it lands on the `div`. `alert_variants_test.exs` holds the kinds the game raises and
the ones the stylesheet draws to each other. What an action says, a refusal included, is its flash,
dropped on the next arrival unless the action itself moved you there; a dismissible notice that
nothing cleared on arrival once followed players everywhere.

**Every table in the game is one component.** `Controls.data_table/1` draws the container, the
header row and the `<table>`; the rows are the caller's `<tbody>`, and anything else handed to it
lands on the `<table>`. A sort, when one is needed, is the server's and never the DOM's: a patch
would undo a DOM sort and redo it after, moving every row twice. `legacy/` has the sortable version.

**What the reader chooses is kept as `<kind>:<id>`, through `hooks/kept.js` and nowhere else.**
`panel:inventory` is a fold and `sound:effects` the sound switch, kept only while it is off, and
`recall` and `keep` are the only code that touches `localStorage` for either, so a new thing that
remembers takes a kind and writes no storage code of its own. A fold
is the browser's alone: the server renders the template's state and the hook corrects it on mount.
Give a kind to the server only when the server must know it to render.

**`class` and `style` render whatever they are given.** Every other attribute disappears when its
value is nil; those two come out as `class="panel "` and `style=""`, on every panel in the game.
Build them before the tag — `classes/1` in `Controls` — or spread a keyword list into
it, which contributes no attribute at all when it is empty.

**Test fixtures live in `test/`, never in `priv/`.** `priv/` ships inside the release.

**A run that nobody comes back to goes missing, never deleted.** The 30-day retirement takes a
character's session without touching its row, so it can never be played again but is still there.
Anything that lists characters says `active` for "has a session", never the session itself.

**Do not over-explain.** One to three lines, why not what, never a paragraph. A hard limit, not a
preference — it is the rule broken most often.

A comment earns its place by saying what the code cannot: a constraint, a trap, a decision that
looks wrong until you know why. It never narrates the line, restates the identifier, or recounts
how the bug was found. Needing more than three lines means the knowledge belongs in this file
instead. CSS and HEEx need it least — a rule wanting a paragraph usually wants a better selector.
Moduledocs may run to a short paragraph; nothing else may.

**Dropping a column drops every index that mentions it — including in a WHERE.** A log table once
lost its only useful index that way, silently, and went back to scanning the whole table for every
new character. `schema_test.exs` names the indexes the game cannot go without; add to it when you
add one. A query-plan assertion cannot do this job — Postgres rightly prefers a sequential scan over
the few rows a test inserts.

**A round trip costs ~0.8ms; the query usually costs less.** Measured against the real server, not
guessed. So prefer one statement over a clever plan: splitting an OR-chain into two index-only
COUNTs once made a rank lookup *slower* until it was folded back into one `UNION ALL`. `EXPLAIN
ANALYZE` reports server time and says nothing about the wire — time the wall clock before believing
it. And time the code path that ships, not hand-written SQL: `Repo.query!` parses and plans on every
call where Ecto caches the prepared statement.

**An empty environment variable is not an absent one.** `System.get_env("DB_PORT", "5432")` returns
`""`, not the default, and parsing it crashes at boot. Compose passes a missing key through as
empty, so every `${VAR}` it forwards needs a `:-default`.

**Ownership is set as the files land, never chowned afterwards.** `COPY --chown=app:app` costs
nothing; a `RUN chown -R app:app /app` after the copy writes a second copy of the whole release into
its own layer — 34MB of a 53MB image. The `/app` directory itself still needs chowning, because the
release puts its runtime config under it.

**Migrations ship inside the release image.** `MiniLineage.Release.migrate()` run from a stale
image reports "Migrations already up" and means it — about the migrations that image carries.
Rebuild before you believe it.

**`compile_env` only for values that are constant per environment.** `:build_label` qualifies;
`:app_version` does not — it is derived from `git rev-parse HEAD`, so marking it compile-time makes
Mix compare the baked sha against the current one and refuse every task after the next commit.
Read a value that moves with `Application.get_env/2` at runtime, and put a build-time requirement
in a release step in `mix.exs`, which runs at the moment a thing becomes deployable.

**A setting an environment overrides is defaulted in `config.exs` and nowhere else.** The code reads
it with `compile_env!` or `fetch_env!`, never with a default of its own, so there is one value to
change and a missing key fails at compile or boot rather than falling back to a stale copy. Only
`:app_version` is optional. A value no environment changes is not a setting: it is a rule of the
game and lives in `Constants`.

<!-- usage-rules-start -->

<!-- phoenix:elixir-start -->

## Elixir guidelines

- Elixir lists **do not support index based access via the access syntax**

  **Never do this (invalid)**:

      i = 0
      mylist = ["blue", "green"]
      mylist[i]

  Instead, **always** use `Enum.at`, pattern matching, or `List` for index based list access, ie:

      i = 0
      mylist = ["blue", "green"]
      Enum.at(mylist, i)

- Elixir variables are immutable, but can be rebound, so for block expressions like `if`, `case`, `cond`, etc
  you *must* bind the result of the expression to a variable if you want to use it and you CANNOT rebind the result inside the expression, ie:

      # INVALID: we are rebinding inside the `if` and the result never gets assigned
      if connected?(socket) do
        socket = assign(socket, :val, val)
      end

      # VALID: we rebind the result of the `if` to a new variable
      socket =
        if connected?(socket) do
          assign(socket, :val, val)
        end

- **Never** nest multiple modules in the same file as it can cause cyclic dependencies and compilation errors
- **Never** use map access syntax (`changeset[:field]`) on structs as they do not implement the Access behaviour by default. For regular structs, you **must** access the fields directly, such as `my_struct.field` or use higher level APIs that are available on the struct if they exist, `Ecto.Changeset.get_field/2` for changesets
- Elixir's standard library has everything necessary for date and time manipulation. Familiarize yourself with the common `Time`, `Date`, `DateTime`, and `Calendar` interfaces by accessing their documentation as necessary. **Never** install additional dependencies unless asked or for date/time parsing (which you can use the `date_time_parser` package)
- Don't use `String.to_atom/1` on user input (memory leak risk)
- Predicate function names should not start with `is_` and should end in a question mark. Names like `is_thing` should be reserved for guards
- Elixir's builtin OTP primitives like `DynamicSupervisor` and `Registry`, require names in the child spec, such as `{DynamicSupervisor, name: MyApp.MyDynamicSup}`, then you can use `DynamicSupervisor.start_child(MyApp.MyDynamicSup, child_spec)`
- Use `Task.async_stream(collection, callback, options)` for concurrent enumeration with back-pressure. The majority of times you will want to pass `timeout: :infinity` as option

## Mix guidelines

- Read the docs and options before using tasks (by using `mix help task_name`)
- To debug test failures, run tests in a specific file with `mix test test/my_test.exs` or run all previously failed tests with `mix test --failed`
- `mix deps.clean --all` is **almost never needed**. **Avoid** using it unless you have good reason

## Test guidelines

- **Always use `start_supervised!/1`** to start processes in tests as it guarantees cleanup between tests
- **Avoid** `Process.sleep/1` and `Process.alive?/1` in tests
  - Instead of sleeping to wait for a process to finish, **always** use `Process.monitor/1` and assert on the DOWN message:

      ref = Process.monitor(pid)
      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}

   - Instead of sleeping to synchronize before the next call, **always** use `_ = :sys.get_state/1` to ensure the process has handled prior messages
<!-- phoenix:elixir-end -->

<!-- phoenix:phoenix-start -->
## Phoenix guidelines

- Remember Phoenix router `scope` blocks include an optional alias which is prefixed for all routes within the scope. **Always** be mindful of this when creating routes within a scope to avoid duplicate module prefixes.

- You **never** need to create your own `alias` for route definitions! The `scope` provides the alias, ie:

      scope "/admin", AppWeb.Admin do
        pipe_through :browser

        live "/users", UserLive, :index
      end

  the UserLive route would point to the `AppWeb.Admin.UserLive` module

- `Phoenix.View` no longer is needed or included with Phoenix, don't use it
<!-- phoenix:phoenix-end -->

<!-- phoenix:ecto-start -->
## Ecto Guidelines

- **Always** preload Ecto associations in queries when they'll be accessed in templates, ie a message that needs to reference the `message.user.email`
- Remember `import Ecto.Query` and other supporting modules when you write `seeds.exs`
- `Ecto.Schema` fields always use the `:string` type, even for `:text`, columns, ie: `field :name, :string`
- `Ecto.Changeset.validate_number/2` **DOES NOT SUPPORT the `:allow_nil` option**. By default, Ecto validations only run if a change for the given field exists and the change value is not nil, so such as option is never needed
- You **must** use `Ecto.Changeset.get_field(changeset, :field)` to access changeset fields
- Fields which are set programmatically, such as `user_id`, must not be listed in `cast` calls or similar for security purposes. Instead they must be explicitly set when creating the struct
- **Always** invoke `mix ecto.gen.migration migration_name_using_underscores` when generating migration files, so the correct timestamp and conventions are applied
<!-- phoenix:ecto-end -->

<!-- phoenix:html-start -->
## Phoenix HTML guidelines

- Phoenix templates **always** use `~H` or .html.heex files (known as HEEx), **never** use `~E`
- **Always** use the imported `Phoenix.Component.form/1` and `Phoenix.Component.inputs_for/1` function to build forms. **Never** use `Phoenix.HTML.form_for` or `Phoenix.HTML.inputs_for` as they are outdated
- When building forms **always** use the already imported `Phoenix.Component.to_form/2` (`assign(socket, form: to_form(...))` and `<.form for={@form} id="msg-form">`), then access those forms in the template via `@form[:field]`
- **Always** add unique DOM IDs to key elements (like forms, buttons, etc) when writing templates, these IDs can later be used in tests (`<.form for={@form} id="product-form">`)
- For "app wide" template imports, you can import/alias into the `my_app_web.ex`'s `html_helpers` block, so they will be available to all LiveViews, LiveComponent's, and all modules that do `use MyAppWeb, :html` (replace "my_app" by the actual app name)

- Elixir supports `if/else` but **does NOT support `if/else if` or `if/elsif`**. **Never use `else if` or `elseif` in Elixir**, **always** use `cond` or `case` for multiple conditionals.

  **Never do this (invalid)**:

      <%= if condition do %>
        ...
      <% else if other_condition %>
        ...
      <% end %>

  Instead **always** do this:

      <%= cond do %>
        <% condition -> %>
          ...
        <% condition2 -> %>
          ...
        <% true -> %>
          ...
      <% end %>

- HEEx require special tag annotation if you want to insert literal curly's like `{` or `}`. If you want to show a textual code snippet on the page in a `<pre>` or `<code>` block you *must* annotate the parent tag with `phx-no-curly-interpolation`:

      <code phx-no-curly-interpolation>
        let obj = {key: "val"}
      </code>

  Within `phx-no-curly-interpolation` annotated tags, you can use `{` and `}` without escaping them, and dynamic Elixir expressions can still be used with `<%= ... %>` syntax

- HEEx class attrs support lists, but you must **always** use list `[...]` syntax. You can use the class list syntax to conditionally add classes, **always do this for multiple class values**:

      <a class={[
        "px-2 text-white",
        @some_flag && "py-5",
        if(@other_condition, do: "border-red-500", else: "border-blue-100"),
        ...
      ]}>Text</a>

  and **always** wrap `if`'s inside `{...}` expressions with parens, like done above (`if(@other_condition, do: "...", else: "...")`)

  and **never** do this, since it's invalid (note the missing `[` and `]`):

      <a class={
        "px-2 text-white",
        @some_flag && "py-5"
      }> ...
      => Raises compile syntax error on invalid HEEx attr syntax

- **Never** use `<% Enum.each %>` or non-for comprehensions for generating template content, instead **always** use `<%= for item <- @collection do %>`
- HEEx HTML comments use `<%!-- comment --%>`. **Always** use the HEEx HTML comment syntax for template comments (`<%!-- comment --%>`)
- HEEx allows interpolation via `{...}` and `<%= ... %>`, but the `<%= %>` **only** works within tag bodies. **Always** use the `{...}` syntax for interpolation within tag attributes, and for interpolation of values within tag bodies. **Always** interpolate block constructs (if, cond, case, for) within tag bodies using `<%= ... %>`.

  **Always** do this:

      <div id={@id}>
        {@my_assign}
        <%= if @some_block_condition do %>
          {@another_assign}
        <% end %>
      </div>

  and **Never** do this – the program will terminate with a syntax error:

      <%!-- THIS IS INVALID NEVER EVER DO THIS --%>
      <div id="<%= @invalid_interpolation %>">
        {if @invalid_block_construct do}
        {end}
      </div>
<!-- phoenix:html-end -->

<!-- phoenix:liveview-start -->
## Phoenix LiveView guidelines

- **Never** use the deprecated `live_redirect` and `live_patch` functions, instead **always** use the `<.link navigate={href}>` and  `<.link patch={href}>` in templates, and `push_navigate` and `push_patch` functions LiveViews
- **Avoid LiveComponent's** unless you have a strong, specific need for them
- LiveViews should be named like `AppWeb.WeatherLive`, with a `Live` suffix. When you go to add LiveView routes to the router, the default `:browser` scope is **already aliased** with the `AppWeb` module, so you can just do `live "/weather", WeatherLive`

### LiveView streams

- **Always** use LiveView streams for collections for assigning regular lists to avoid memory ballooning and runtime termination with the following operations:
  - basic append of N items - `stream(socket, :messages, [new_msg])`
  - resetting stream with new items - `stream(socket, :messages, [new_msg], reset: true)` (e.g. for filtering items)
  - prepend to stream - `stream(socket, :messages, [new_msg], at: -1)`
  - deleting items - `stream_delete(socket, :messages, msg)`

- When using the `stream/3` interfaces in the LiveView, the LiveView template must 1) always set `phx-update="stream"` on the parent element, with a DOM id on the parent element like `id="messages"` and 2) consume the `@streams.stream_name` collection and use the id as the DOM id for each child. For a call like `stream(socket, :messages, [new_msg])` in the LiveView, the template would be:

      <div id="messages" phx-update="stream">
        <div :for={{id, msg} <- @streams.messages} id={id}>
          {msg.text}
        </div>
      </div>

- LiveView streams are *not* enumerable, so you cannot use `Enum.filter/2` or `Enum.reject/2` on them. Instead, if you want to filter, prune, or refresh a list of items on the UI, you **must refetch the data and re-stream the entire stream collection, passing reset: true**:

      def handle_event("filter", %{"filter" => filter}, socket) do
        # re-fetch the messages based on the filter
        messages = list_messages(filter)

        {:noreply,
         socket
         |> assign(:messages_empty?, messages == [])
         # reset the stream with the new messages
         |> stream(:messages, messages, reset: true)}
      end

- LiveView streams *do not support counting or empty states*. If you need to display a count, you must track it using a separate assign. For empty states, you can use Tailwind classes:

      <div id="tasks" phx-update="stream">
        <div class="hidden only:block">No tasks yet</div>
        <div :for={{id, task} <- @streams.tasks} id={id}>
          {task.name}
        </div>
      </div>

  The above only works if the empty state is the only HTML block alongside the stream for-comprehension.

- When updating an assign that should change content inside any streamed item(s), you MUST re-stream the items
  along with the updated assign:

      def handle_event("edit_message", %{"message_id" => message_id}, socket) do
        message = Chat.get_message!(message_id)
        edit_form = to_form(Chat.change_message(message, %{content: message.content}))

        # re-insert message so @editing_message_id toggle logic takes effect for that stream item
        {:noreply,
         socket
         |> stream_insert(:messages, message)
         |> assign(:editing_message_id, String.to_integer(message_id))
         |> assign(:edit_form, edit_form)}
      end

  And in the template:

      <div id="messages" phx-update="stream">
        <div :for={{id, message} <- @streams.messages} id={id} class="flex group">
          {message.username}
          <%= if @editing_message_id == message.id do %>
            <%!-- Edit mode --%>
            <.form for={@edit_form} id="edit-form-#{message.id}" phx-submit="save_edit">
              ...
            </.form>
          <% end %>
        </div>
      </div>

- **Never** use the deprecated `phx-update="append"` or `phx-update="prepend"` for collections

### LiveView JavaScript interop

- Remember anytime you use `phx-hook="MyHook"` and that JS hook manages its own DOM, you **must** also set the `phx-update="ignore"` attribute
- **Always** provide an unique DOM id alongside `phx-hook` otherwise a compiler error will be raised

LiveView hooks come in two flavors, 1) colocated js hooks for "inline" scripts defined inside HEEx,
and 2) external `phx-hook` annotations where JavaScript object literals are defined and passed to the `LiveSocket` constructor.

#### Inline colocated js hooks

**Never** write raw embedded `<script>` tags in heex as they are incompatible with LiveView.
Instead, **always use a colocated js hook script tag (`:type={Phoenix.LiveView.ColocatedHook}`)
when writing scripts inside the template**:

    <input type="text" name="user[phone_number]" id="user-phone-number" phx-hook=".PhoneNumber" />
    <script :type={Phoenix.LiveView.ColocatedHook} name=".PhoneNumber">
      export default {
        mounted() {
          this.el.addEventListener("input", e => {
            let match = this.el.value.replace(/\D/g, "").match(/^(\d{3})(\d{3})(\d{4})$/)
            if(match) {
              this.el.value = `${match[1]}-${match[2]}-${match[3]}`
            }
          })
        }
      }
    </script>

- colocated hooks are automatically integrated into the app.js bundle
- colocated hooks names **MUST ALWAYS** start with a `.` prefix, i.e. `.PhoneNumber`

#### External phx-hook

External JS hooks (`<div id="myhook" phx-hook="MyHook">`) must be placed in `assets/js/` and passed to the
LiveSocket constructor:

    const MyHook = {
      mounted() { ... }
    }
    let liveSocket = new LiveSocket("/live", Socket, {
      hooks: { MyHook }
    });

#### Pushing events between client and server

Use LiveView's `push_event/3` when you need to push events/data to the client for a phx-hook to handle.
**Always** return or rebind the socket on `push_event/3` when pushing events:

    # re-bind socket so we maintain event state to be pushed
    socket = push_event(socket, "my_event", %{...})

    # or return the modified socket directly:
    def handle_event("some_event", _, socket) do
      {:noreply, push_event(socket, "my_event", %{...})}
    end

Pushed events can then be picked up in a JS hook with `this.handleEvent`:

    mounted() {
      this.handleEvent("my_event", data => console.log("from server:", data));
    }

Clients can also push an event to the server and receive a reply with `this.pushEvent`:

    mounted() {
      this.el.addEventListener("click", e => {
        this.pushEvent("my_event", { one: 1 }, reply => console.log("got reply from server:", reply));
      })
    }

Where the server handled it via:

    def handle_event("my_event", %{"one" => 1}, socket) do
      {:reply, %{two: 2}, socket}
    end

### LiveView tests

- `Phoenix.LiveViewTest` module and `LazyHTML` (included) for making your assertions
- Form tests are driven by `Phoenix.LiveViewTest`'s `render_submit/2` and `render_change/2` functions
- Come up with a step-by-step test plan that splits major test cases into small, isolated files. You may start with simpler tests that verify content exists, gradually add interaction tests
- **Always reference the key element IDs you added in the LiveView templates in your tests** for `Phoenix.LiveViewTest` functions like `element/2`, `has_element/2`, selectors, etc
- **Never** tests again raw HTML, **always** use `element/2`, `has_element/2`, and similar: `assert has_element?(view, "#my-form")`
- Instead of relying on testing text content, which can change, favor testing for the presence of key elements
- Focus on testing outcomes rather than implementation details
- Be aware that `Phoenix.Component` functions like `<.form>` might produce different HTML than expected. Test against the output HTML structure, not your mental model of what you expect it to be
- When facing test failures with element selectors, add debug statements to print the actual HTML, but use `LazyHTML` selectors to limit the output, ie:

      html = render(view)
      document = LazyHTML.from_fragment(html)
      matches = LazyHTML.filter(document, "your-complex-selector")
      IO.inspect(matches, label: "Matches")

### Form handling

#### Creating a form from params

If you want to create a form based on `handle_event` params:

    def handle_event("submitted", params, socket) do
      {:noreply, assign(socket, form: to_form(params))}
    end

When you pass a map to `to_form/1`, it assumes said map contains the form params, which are expected to have string keys.

You can also specify a name to nest the params:

    def handle_event("submitted", %{"user" => user_params}, socket) do
      {:noreply, assign(socket, form: to_form(user_params, as: :user))}
    end

#### Creating a form from changesets

When using changesets, the underlying data, form params, and errors are retrieved from it. The `:as` option is automatically computed too. E.g. if you have a user schema:

    defmodule MyApp.Users.User do
      use Ecto.Schema
      ...
    end

And then you create a changeset that you pass to `to_form`:

    %MyApp.Users.User{}
    |> Ecto.Changeset.change()
    |> to_form()

Once the form is submitted, the params will be available under `%{"user" => user_params}`.

In the template, the form form assign can be passed to the `<.form>` function component:

    <.form for={@form} id="todo-form" phx-change="validate" phx-submit="save">
      <.input field={@form[:field]} type="text" />
    </.form>

Always give the form an explicit, unique DOM ID, like `id="todo-form"`.

#### Avoiding form errors

**Always** use a form assigned via `to_form/2` in the LiveView. (This project has no `<.input>`
component — write the input directly — but the `@form[:field]` access below still applies.)

    <%!-- ALWAYS do this (valid) --%>
    <.form for={@form} id="my-form">
      <.input field={@form[:field]} type="text" />
    </.form>

And **never** do this:

    <%!-- NEVER do this (invalid) --%>
    <.form for={@changeset} id="my-form">
      <.input field={@changeset[:field]} type="text" />
    </.form>

- You are FORBIDDEN from accessing the changeset in the template as it will cause errors
- **Never** use `<.form let={f} ...>` in the template, instead **always use `<.form for={@form} ...>`**, then drive all form references from the form assign as in `@form[:field]`. The UI should **always** be driven by a `to_form/2` assigned in the LiveView module that is derived from a changeset
<!-- phoenix:liveview-end -->

<!-- usage-rules-end -->