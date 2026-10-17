---
name: new-page
description: Every file and test a new screen touches in this game, as one checklist. Use when building a new page, screen, place or route (a shop, a trainer, a guild, a hunting ground, a town service), or adding a new dropdown (select_action) or table to an existing page.
---

# A new page

AGENTS.md holds each rule; this is the order they bite in, as the guild page (`/<village>/guild`)
was wired end to end. A place is `{screen, town}`. Work down the list and tick what applies.

## 1. The rule first

A new place to stand starts in `docs/rules.md`, its table in `Rules`, read back by `rules_test.exs`
(a roadmap entry first if it is a new system). A name or number comes from `docs/canon/`,
researched in first if missing.

## 2. Its address

- `router.ex`: a literal route generated from the rules tables (`for slug <- Paths.villages()`),
  never a pattern or glob.
- `Paths.for_screen/1`: a clause for `{screen, town}` placed before the catch-all
  `for_screen({screen, _town})`, or an `@routes` entry for a page with no town.
- `GameLive.requested_place/3`: a town-scoped `live_action` joins the guard list of the clause that
  reads the town from the URI.
- `paths_test.exs`: the place in `places/0` (every route linked to, every link routed), and in the
  town-of-address test's screen list if it stands in a town.

## 3. The gate

- `Access.pin_screen/2`: a clause saying exactly who may stand there (a readable page goes in
  `@readable` instead). Never widen an existing clause to make the new one work.
- `@in_town` if the sidebar belongs beside it (`Access.sidebar?/1`), and `access_test.exs`'s
  sidebar test with it.
- `access_test.exs`: what it allows AND what it still refuses (another town, a visitor, another
  race's home).

## 4. The way there

- A place reached from a town is an option in the town's dropdown (`Screens.town_places/1`) and its
  name in `GameLive`'s `@inner`, which the `navigate` clause walks to; never a link. A link is only
  for what is not a place to go from a town (the inventory, the character page).
- The page's own dropdown names its way back as its placeholder (`🚪 Traders`), and its event's
  empty-choice `handle_event` clause walks back to the town; no back link.

## 5. The screen

- `Screens.screen/1` clause, and the screen in the not-started guard above them all, so a reset in
  another tab draws nothing rather than raise on a nil field.
- Its heading: a `@titles` entry or a `title/2` clause (else it reads "Mini Lineage"), and `icon/2`.
- `panels/3` lists its panels; `Layouts.app` wraps each in `Controls.panel` and `screen/1` draws
  each one's body. A screen never writes `Controls.panel` itself.
- What it reads comes from `Snapshot.build/1`: a new field there goes into the not-started `@empty`
  too (`snapshot_test.exs` checks both have every key). New player state goes through `Player` and
  `Characters.Serde`, which writes it.
- Figures the player watches change are `<.figure>`; Adena is 🪙 and `.adena`.
- Prose through `Format.stat/1`, `Format.adena/1`, `Format.remaining/1`; no em dash in game prose; HP
  is mended; named entities; anchors flush. If it shows stats, add it to `stat_names_test.exs`'s
  screens. Its look goes in `assets/css`, by `docs/design.md`.

## 6. Tables

- `<.data_table>` (the short form, as `Screens` writes it), rows ordered by `Controls.sort_rows/3`.
- `Screens.sortable/1`: its keys and the default it opens on.
- `table_sort_test.exs` `@pages`: the path and each table's default.
- Shelves are separate `<tbody>`s, with a centred heading row and a dropdown `group` each when there
  is more than one.

## 7. Acting

- One `<.select_action id="a-literal-id" ...>` and its button, never a button per row. The id must be
  a literal and the tag the short form: the walkthrough finds every dropdown in the source by that
  pattern. An option's `group` shelves it; its `action` and `variant` are what the button says and
  looks like once it is picked, for a page with several verbs. The component writes "Pick".
- A `handle_event` going through `apply_action/3` into an `Actions` function that returns
  `{player, {:ok, flash}}` or `{player, {:error, code, message}}`, the message from `@errors`. Its
  refusals are tested in the domain's own file (`trainer_test.exs`, `shop_test.exs`,
  `potions_test.exs`), and the page gets its own `<page>_page_test.exs` LiveView test, a refusal
  included.
- A refusal is always drawn `:danger` by `apply_action/3`. A success's flash is `:success` for
  something gained (it chimes), `:info` for a rearrangement or a setting, and `:danger` only for a
  success that hurts (a weapon its skill cannot use). A new level brings its own gold alert.
- Options are built only from what the player's own actions change, never from a tick (HP, MP,
  auras, the hour), or a push rebuilds an open list.

## 8. The browser

- `e2e/walkthrough.mjs`: visit the page and call `holdEach()` there, or the dropdown tour fails on
  its `select_action`. Read a figure's `data-value`, never its text; hand Playwright functions.
- A new selector, or a change to what an element is, means `mix e2e` as well as `mix precommit`.

## 9. Write it down

- AGENTS.md: "What exists" names the page, its address and its action, and "Web" lists the place
  among the literal routes and what `pin_screen` allows. A new component, hook or shared control
  gets its entry in the same change.
- Done is `mix precommit` and `mix e2e`, each new test seen failing first.
