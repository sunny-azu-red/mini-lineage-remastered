This is Mini-Lineage Remastered: a text-based RPG in Elixir, Phoenix LiveView and OTP.

## This project, specifically

The generic Phoenix guidance below is worth reading, but where it disagrees with this list, this
list wins — several generator defaults do not exist here.

- **There is no `core_components.ex`.** It was deleted as dead code, so there is no `<.icon>`, no
  `<.input>`, and no `<.flash_group>`. Every control is hand-written HEEx in
  `lib/mini_lineage_web/components/`. Ignore any advice below that reaches for those.
- **There is no HTTP client** — no `Req`, no `:httpoison`. The game calls nothing outward.
- **There is no authentication**, so no `current_scope`, no `live_session` scoping, no user table.
  A browser is tied to a character by a signed session cookie and nothing else.
- **There are no LiveView streams.** One character's state is one assign.
- The database is **PostgreSQL via Postgrex**. Character state is a single `jsonb` document.
- One `GenServer` per character under a `DynamicSupervisor` + `Registry`. Anything that mutates a
  character goes through its process, never straight to the database.
- `<Layouts.app>` does exist and every LiveView template starts with it.
- **One LiveView, one dispatcher, a module per page.** `GameLive` holds no game state and routes
  everything through `Access.pin_screen/2`. `Screens.screen/1` picks the page: the run's own four
  live in `Screens` itself, and the pages that outlive a run — `Screens.Shop`, `Screens.Record`,
  `Screens.Halls`, `Screens.Tome` — each have a module. Anything a page reaches for but does not
  own (the panel card, the alerts, the select-and-button form, `<.back_link>`, `<.stamp>`) is in
  `Controls`.
  `Screens.aside/1` is the same dispatch for what a screen puts BELOW its panel rather than inside
  it, through `<Layouts.app>`'s `:aside` slot — only the record's Chronicle so far, which is longer
  than everything else on that page put together and crowds out what the panel is named for.

### Working here

- **`.env.test` decides the browser suites' port, never `.env`.** `mix e2e` runs in `:dev`, where
  `.env` would hand it `PORT=4000` and it would sit waiting on the development server. It gets away
  with this only because a Mix task does not start the application; adding `app.start` would break
  it silently.
- **Database tests cannot be `async: true`.** A character lives in a GenServer started by a
  `DynamicSupervisor`, so the sandbox cannot trace ownership from the test process to it. Shared
  mode bridges that, and shared mode means serial. This is our architecture, not the driver — it
  was just as true on MySQL.
- **Nor can a test that claims a registered name.** `cheat_test.exs` stands in for the statistics
  collector by registering itself under its name; the name is global, so every async module that
  creates a character posts its own increments into that mailbox and the drain reads them as the
  run under test's. It failed about one seed in eight.
- Migrations commit their DDL implicitly, which ends the sandbox transaction. That is why
  `release_test` checks configuration rather than running one.
- `mix precommit` before you call anything done, and `mix e2e` for anything the browser renders —
  a screen, a hook, a selector, a rule that changes what an element *is*. ExUnit reads 0% for the
  whole web layer because the browser suites are not instrumented, not because it is untested.
  A change that only moves colour values is the exception: no suite can fail on a hex, and running
  them there buys nothing but minutes and their own flakes. `mix precommit`, then look at it.
- Show a new test failing before you claim it passes. Break the thing it covers, watch it go red,
  put it back. A test written after the fix and never seen to fail is decoration.

### Rules that are not negotiable

Each of these is here because it was got wrong once.

**Never assert on a roll of the dice.** Not in the browser suites, not in ExUnit. Pin the source
(`Rng.put_source/1`, or `Test.Lcg` for the golden master's stream), or make the character tanky
enough that no roll changes the answer — `health: 5_000` is the idiom. A fatal fight counts no
battle, which is all it takes to make a counter assertion pass for months and fail in CI once.
What the dice decide belongs in `balance_golden_test.exs`, which seeds them.

A randomly drawn *string* is the same trap wearing a disguise. Death reasons and narrative lines
are drawn from pools, and some carry an apostrophe that HEEx escapes — so matching one against
rendered HTML passes or fails on the roll. Where a test renders a drawn line, fix it first
(`%{Player.kill(p) | death_reason: "..."}`); that it came from the pool at all is a separate test's
job, against the struct rather than the page.

**A formatter with a client-side twin is held to a table.** Two are duplicated on purpose.
`Format.adena` and `shortAdena` in `hooks.js`: the count-up animation formats its own frames, and
without a client-side copy the number would change format mid-count. `Format.countdown` and
`timerLabel`: the server renders an effect's first frame and the hook repaints it every second.
`Format.remaining` and `remainingLabel` are the same pair said in a sentence, for the record's
Blessings & Afflictions — a badge has room for "1m" and a paragraph has room for "1m 30s".
Each pair reads one fixture — `test/fixtures/adena_format.json`, `test/fixtures/effect_timer.json`
— from `format_test.exs` on the Elixir side and `walkthrough.mjs` on the JavaScript one. Change
either implementation, change its table, and both tests will tell you. Anything else the two
languages both format wants the same treatment before it gets a second copy.

**Mutable working state is a document; anything sorted on is a column.** `characters` is owned by
a process and only ever read whole, so it is one `jsonb` blob — but the fields the board ranks on
are GENERATED columns over that document, never written by application code, so they cannot drift
from it. Under PG18 write `STORED` explicitly or you get a VIRTUAL column that cannot be indexed.
Anything that grows with play — a battle history, an inventory, a mail box — gets its own table.
Put it in the document and every save rewrites all of it, buffering or not.

**A character has two ids and they must never be confused.** `id` is public and goes in board
links; `session_id` is the cookie and is a credential. A public id that is also a session lets
anyone play as a champion by pasting their link into a cookie. The board selects into plain maps
rather than `%Record{}` for exactly this reason — a struct carries a `session_id` key.

The session names the BROWSER, not the run, so it outlives both. Starting over archives the old
row and gives the same session a new character; nothing needs a new cookie, and therefore nothing
needs to leave the socket.

**Writes follow the player, not the clock.** What the player did is written before they are told it
worked: creation, a fight, a purchase, death, the cheat. The passage of time — passive
regeneration, which screen they wandered to — is buffered and rides along with the next of those,
or with `terminate/2`. The decision is derived from the struct in `Characters.Server`, never
declared at a call site, because a call site can forget.

**The URL is where you are.** Start, Town and Game Over are one run's three states and share `/`;
`Access.pin_screen/2` decides which. Somewhere you can stand — the Battleground, a shop, the
Character screen — gets a URL of its own. A state that happens to you does not.

**Do not widen a guard to make something work.** `@dead_allowed` in `Access`, the check in
`e2e/reset.sh` that refuses the database `.env` names, the purchase preconditions: each one is the
boundary, and there is a test asserting
what it still refuses. If a guard is in the way, the thing you are building is probably wrong.

**What the player can see is what heals them.** The 🌿 aura and the regeneration tick are one
condition, not two copies of it: `process_regen_tick/1` heals by whatever rate the aura carries, so
an icon with no healing behind it — or healing with no icon — cannot happen. `regen_aura/2` takes
its effect list as an argument rather than reading it back, because `active_effects/1` is what
calls it.

**The cookie is only legible to the secret that signed it.** dev and prod read the same `.env`,
so `config/runtime.exs` hands both the same `SECRET_KEY_BASE` — otherwise switching between them
mints a new session and the character looks lost while sitting in the table untouched. Dev falls
back to the secret committed in `config/dev.exs`, so a clone with no `.env` still boots.

**An anchor wraps its text and nothing else.** A newline inside one renders as a space, and the
underline covers it — which is how the Halls link came to underline the gap before the medal and
the footer the gap after the sha. Where the attributes force the tag open across lines, keep the
content flush against `>` and `</`; where the label is long, name it above the `~H` rather than
letting the formatter break it inside the tag. Buttons are exempt, being padded boxes.

**Declare a property only where the element would not otherwise have it.** Either it does not
inherit — form controls and buttons take no font or colour from `body`, which is measurable and was
— or it differs from what it does. Restating the inherited value gives `body` a second place to be
changed and no second effect, so `.data-table td`, `h2`, `h3` and `.stat-value` say nothing about
colour while `.stat-label` and `th` do. If a container is ever made secondary, the children that
must stay primary will need to say so then; adding it in anticipation is how the two drift apart.

**A panel header's contents are placed by the band, never by themselves.** These are capitals, and
a font's em box carries descender room they never use, so centred they sit high — `.panel-header`
is padded 9 over 7 to answer that, and every child moves with it. It used to be a `margin-top` on
the title and half of one on the effects strip, which is why the chevron could not line up with the
words: three things were being centred by three different rules. Line-height cannot do this job —
it is symmetric by definition, and the correction is not.

**Size is hierarchy, never container.** 13px is anything you read — prose, an alert, a table cell —
because an alert set a step under the paragraph above it reads as a different kind of thing when it
is the same kind. 12px is a control or the compact sidebar, 11px a column label or the footer. The
headings run h1 for the screen the panel names, h2 for a section inside it, h3 below that; the
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

**A class per thing the game names, never per colour it is drawn in.** `.adena` and `.level` and
`.aura` all resolve to `--gold` today and are grouped for it in `base.css`, but they are written
apart, because the moment one of them should move the others must not come with it. That is the
whole point: the group is an observation about today, the name is the thing. A class named after
its colour cannot say which of the things wearing it you meant — `.hp` was carrying health, Max HP,
Physical Attack, deaths, and cheaters struck from the record, and no one of them could be retuned.

So: `.hp .attack .deaths .debuff` are what a run loses and what takes it; `.heal .regen .buff` give
it back; `.adena .level .aura` are what it is worth; `.ambush .cowards .date .timer` are read but
not acted on; `.defense .damage` turn things aside; `.battles .kills .players .purchases` are
things counted; `.crit` stands alone; `.xp .heretics` are what the arcane touches, earned or
struck out for; `.equipped` is what a run carries, quieter than the sentence around it because a
blade's NAME is not the news, the number beside it is.

These are the game's vocabulary and they are filed under **Values**. What is not a value lives above
them under **Utilities**, which is a deliberate separation and not a heading: `.muted` is the only
absence the game has — the `-` in a shop column for an item that grants no modifier — and takes no
weight, since weight is for a figure competing inside a sentence and that is its opposite.
`.build-development` and `.build-testing` are there too: which build serves the page is something
the PAGE knows, not something a player reads. A name that belongs in neither basket belongs in
neither file.

An effect's name wears its own kind (`.buff`, `.debuff`, `.aura`) and takes its colour from the
vocabulary like any other value. The BADGE over its emoji does not: `--text-success-bright` and
`--text-danger` are lighter, and the pixel font needs them at that size. Every text colour is a
token; adding a class means putting it in a group, never inventing a hex.

**A token is named for its ROLE, never its family: `--<role>-<name>`.** `--text-`, `--bg-`,
`--border-`, `--wash-`, `--bar-`, `--glow-`, `--shadow-`, `--focus-`. Type `color:` and there is
one prefix to reach for and one word order to remember, and a family stays honest across roles —
HP is `--text-hp` in a sentence and `--bar-hp` in a meter. That pair used to be `--text-hp` and
`--hp-color`, two shades of one family disagreeing about word order, with `--success` the colour
`.heal` wore and `--success-text` the one it did not. Gold is the single exception, because it is
a hue rather than a role: the accent is deliberately text, border, ground and glow at once, and
prefixing it would mean four tokens holding one colour.

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
`--text-hp`, `--text-critical`, `--text-success`, `--text-tally`, `--text-defense`, `--text-xp` — are all
`L* 58` and so read at 5.2 on the panel, which is what makes them peers; they had ranged `L* 57` to
`66` and the tally whispered. Equalising their chroma is the trap, and it was fallen into once: teal
tops out near 39 at any lightness in sRGB, so a shared chroma *is* 39 and the whole set goes pale to
meet the one hue that cannot keep up. True equality across those six peaks at 45, below where the
palette already sat. Each runs to its own ceiling instead, capped at 72.

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

**Every figure counts; only names and dates jump.** A number the player can watch change wears
`data-key` and `data-value` and is animated by `AnimatedValues`, whose hook sits once over whatever
contains them. What an item grants is a figure and counts with the rest — only the item's own name
and the dates beside it jump, having nothing to count through. `data-format="adena"` counts in the
short form; the frames keep the tenth that the settled value drops, because "2.0k" written "2k" is
two characters narrower and the line jumps left and right across every round thousand.

Animate a figure even where it can only move by one today. Measured: a tween of +1 renders the old
number for 137ms and then the new one — a delay, not a flicker — and forty at once hold a median
frame of 16.7ms, which is 60fps with nothing lost. A count reads its distance from the delta, never
from a guess about how far a value can jump, so a turn that one day gives two fights or experience
enough for two levels needs no markup change. The alternative is deciding per figure how far it can
move and being wrong later. The level came off the Halls on that wrong guess and went back on.

A figure and the noun it counts are separate elements, so `Controls.counted/1` exists: at one there
is no figure to tween, because "a cunning ambush" is a word. That splitting is why a test asserting
"12 battles" reads the stripped text and not the markup.

**A screen that shows somebody's figures is pushed to, not polled.** Three topics carry them and
they are keyed differently on purpose. `"character:#{session}"` is the browser's own and carries
what only its owner may act on — its key is a secret, so nobody can watch anybody else, and it is
the session because a run started over mints a new character id and the owner learns the new id
FROM that push. `"record:#{character_id}"` is public, because a record is a public page.
`"statistics"` carries the archives, and carries them when a counter MOVES rather than when it is
written — the collector keeps its own running totals so it can say so without a query, gathered on
the same 500ms window the board uses. Batching the write is about a round trip being expensive;
a broadcast is microseconds, and tying one to the other made the Tome a minute stale.

A push must not announce what cannot yet be read. `Server.run/2` broadcasts AFTER it persists, and
the collector after its counters are in, because a reader answering a push by reading the database
finds nothing otherwise — which is exactly how the chronicle came back empty. It costs about 1.2ms
before a push lands and is worth it.

Anything a record needs live rides in the snapshot rather than being read back: `last_action_at` is
there so a watched record restamps itself without a query. The chronicle is only ever APPENDED to —
a run's fights never change, so a reader keeps the ones it has and asks for the rest. Two signals
say a fight happened, because neither alone is enough: the tally does not count the fight that
killed them, and a narrative can repeat where the numbers do not.

**A browser suite tests the game, not its CSS.** The walkthrough is one character played normally.
A 600ms sweep across the HP bar was checked there and failed about one run in three, taking the
whole suite with it. The gain that triggers it is what matters and is checked instead. Known and
unfixed: a LiveView patch that touches a bar rewrites its class from the template and takes the
running sweep with it — measured at 2ms of its 600 whenever a patch lands, which is most purchases.

**The catalog is cached per VM, so development does not cache it.** `Snapshot.catalog/0` builds
slugs and fills the race templates from code; caching that in `:dev` means editing a narrative
changes nothing until the server restarts. `:e2e` and `:prod` cache, which is what ships.

**A visitor is never written.** A browser that has not chosen a lineage lives in its process and
nothing else: every action that could change it is guarded on `started?`, so nothing marks it dirty
and nothing persists it. That is why the retirement only ever clears sessions and deletes nothing,
and why `characters` has no row without a race. `visitor_test.exs` holds it.

**A deed is gated; the census is not.** `Statistics.increment_for/3` drops everything a
disqualified run *does* — its battles, its plunder, its blood — because the Halls will not list a
coward or a cheat and an aggregate cannot give back what it was already told. Being born and dying
come through the ungated `increment/2` instead: `total_players` is counted at `initialize`, before
anybody can be disqualified, so the census already holds every future coward and heretic. Gate the
exit, and souls arrive and are never accounted for leaving — which printed "0 Champions have
fallen... while a Heretic was struck down", and the Tome tells the Weak Souls and the Heretics as a
few *of* the fallen.

**The registry can name a process that has just stopped.** `Characters.call/3` looks a character up
in the registry directly, which is what keeps every read and write off the `DynamicSupervisor` —
starting a character runs two queries inside the supervisor's own loop, and everyone else would
queue behind them. The price is that a lookup reads ETS and can see an entry whose `DOWN` is still
sitting in the registry's mailbox, so the RETRY goes through the supervisor: registering a name is
handled by the registry itself, behind that DOWN, and by then the stale entry has gone.

**A figure on a page is animated, so a browser suite reads `data-value` and never the text.** The
Halls' XP cell counts up to its new number over 600ms, so `textContent` mid-tween is a frame: a
wait for "has this figure moved" returned on the first one — 3, where the value was 62 — and every
check downstream compared the wrong moment. The attribute is what the server wrote; the text is
what the animation is showing. For the same reason a check against the BOARD waits rather than
reads once: refreshes are coalesced, so a run disqualified a moment ago can still be on the copy
that page was served.

**Every panel in the game is one component.** `Controls.panel/1` draws the card — the header band,
the title, the body — and the differences are options: `heading` for the screen's own h1, and only
that one, `collapsible` and `collapsed` for a header that folds, `max_height` for a body that
scrolls, `stick_to_bottom` for a log that opens on its newest line rather than its first. `id`
names the PANEL, which is what its hook needs; `body_id` and everything else handed to it land on
the BODY, which is what a screen is addressed by — `#screen`, its `PanelFocus` hook and the data
attributes a browser test reads. A panel takes a hook only when something about it moves, so the
error page, which has no LiveView behind it, renders one that cannot ask for JavaScript.

The cap belongs to the body and never to what it holds: the scrollbar then sits against the panel's
edge rather than inside the body's padding.

**A collapse is the reader's, not the template's.** `hidden` and `aria-expanded` are rendered once
for the opening state and belong to the `Panel` hook after that, re-applied on every `updated/0` —
the same reason the HP bar's sweep has to be watched. What the reader last did is kept under
`panel:<id>` in `localStorage` and beats the template on the next mount, so a fold survives a
refresh and a walk away; the id keys the PANEL, not whose record it is.

The whole header band is the control, and it is a BUTTON. It goes nowhere, and a link would say it
did: Space activates a button and scrolls a link, which is the same reason `PanelFocus` refuses to
focus one. `aria-expanded` sits on the header and IS the state, and the chevron turns off it. The
gold line belongs to the BODY as a `border-top`, never to the header as a `border-bottom`: a shut
panel then draws no line closing off what is not there, and leaves no pixel of one in the band.

Opening by hand brings the panel into view, aligned on its BOTTOM, a log's newest lines being
there. Only by hand — a panel restored open from storage, or patched while open, was never asked to
move the page. Nor may it animate into a restored state: the chevron's transition is gated on a
`data-ready` the hook sets two frames in, or every refresh spins it through a state the reader
never left.

**`class` and `style` render whatever they are given.** Every other attribute disappears when its
value is nil; those two come out as `class="panel "` and `style=""`, on every panel in the game.
Build them before the tag — `classes/1` and `cap/1` in `Controls` — or spread a keyword list into
it, which contributes no attribute at all when it is empty.

**Test fixtures live in `test/`, never in `priv/`.** `priv/` ships inside the release.

**A run ends three ways: fallen, going, or missing.** Dead is not the only way to be over — the
30-day retirement takes a character's session without killing it, so it can never be played again.
`Board` says `active` for "has a session", never the session itself, and the board treats a
missing run as finished rather than as one still going.

**One record, one route, two voices.** `/character/:id` is every character's page, yours included —
a record is public because it is on the board, so there is nothing to gate. `Screens.Record` draws
it; pass `mine: false` to speak about somebody rather than to them. They/them is the third person
because the game records no gender, and because it takes the same verb forms as "you", so nothing
but the pronouns moves — which is why the prose forks only where the sentences change shape, not
wherever a verb does.

Yours reads from your own process, not the stored document: `health` is buffered, so the row is
behind by however long you have been resting.

**Every absolute time a player sees goes through `<.stamp>`.** The database stores instants in
`timestamptz` and the server runs in UTC, so only the browser knows what o'clock it is for the
reader. The server-rendered text is the no-JS fallback; the `LocalTime` hook rewrites it. Durations
(`data-remaining-ms`) are exempt — they are the same length everywhere.


**Do not over-explain.** One to three lines, why not what, never a paragraph. A hard limit, not a
preference — it is the rule broken most often.

A comment earns its place by saying what the code cannot: a constraint, a trap, a decision that
looks wrong until you know why. It never narrates the line, restates the identifier, or recounts
how the bug was found. Needing more than three lines means the knowledge belongs in this file
instead. CSS and HEEx need it least — a rule wanting a paragraph usually wants a better selector.
Moduledocs may run to a short paragraph; nothing else may.

**Dropping a column drops every index that mentions it — including in a WHERE.** `battle_log` lost
its only useful index that way, silently, and went back to scanning the whole table for every new
character. `schema_test.exs` names the indexes the game cannot go without; add to it when you add
one. A query-plan assertion cannot do this job — Postgres rightly prefers a sequential scan over
the few rows a test inserts.

**A round trip costs ~0.8ms; the query usually costs less.** Measured against the real server, not
guessed. So prefer one statement over a clever plan: splitting an OR-chain into two index-only
COUNTs made `rank_of` *slower* until it was folded back into one `UNION ALL`. `EXPLAIN ANALYZE`
reports server time and says nothing about the wire — time the wall clock before believing it.
`Store.save` skips its transaction when there is no fight to be consistent with, for the same
reason: `BEGIN` and `COMMIT` are two more trips.

**An empty environment variable is not an absent one.** `System.get_env("DB_PORT", "5432")` returns
`""`, not the default, and parsing it crashes at boot. Compose passes a missing key through as
empty, so every `${VAR}` it forwards needs a `:-default`.

**Ownership is set as the files land, never chowned afterwards.** `COPY --chown=app:app` costs
nothing; a `RUN chown -R app:app /app` after the copy writes a second copy of the whole release into
its own layer — 35MB of an 88MB image. The `/app` directory itself still needs chowning, because the
release puts its runtime config under it.

**Migrations ship inside the release image.** `MiniLineage.Release.migrate()` run from a stale
image reports "Migrations already up" and means it — about the migrations that image carries.
Rebuild before you believe it.

**`compile_env` only for values that are constant per environment.** `:build_label` qualifies;
`:app_version` does not — it is derived from `git rev-parse HEAD`, so marking it compile-time makes
Mix compare the baked sha against the current one and refuse every task after the next commit.
Read a value that moves with `Application.get_env/2` at runtime, and put a build-time requirement
in a release step in `mix.exs`, which runs at the moment a thing becomes deployable.

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