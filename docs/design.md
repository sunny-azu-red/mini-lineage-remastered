# Design

How the game is drawn. What a control IS lives in `AGENTS.md`; this is how it looks. Each rule here
was got wrong once.

## Type

- **Size is hierarchy, never container.** 13px is anything read: prose, an alert, a table cell, a
  sidebar value. 12px is a control. 11px is a label (a column's, a field's) or the footer, set by one
  rule in `base.css` at weight 600, 0.1em, in capitals. The one exception is 10px for the figures and
  labels inside the HP, MP and XP bars, because an 18px bar has no room. A field label's 1px
  `margin-top` is optical: `text-box-trim` is missing from Firefox.
- **The sidebar is 210px.** Widen it before shrinking a value, and never without asking.
- **A heading takes no size or weight from the browser**, only from its class.
- **Weight answers "which of these matters?", so a table never needs it.** Tabular figures are on
  `body`, so columns line up and a counting number doesn't reflow its line. Weight is scoped to
  values inside `p` and `li`, as one `:is(p, li) :is(…)` list, so adding a name is one edit. Only
  Inter 400, 500 and 600 are loaded; 700 is faked.
- **Declare a property only where the element would not otherwise have it.** Either it doesn't
  inherit (form controls and buttons take no font or colour from `body`) or it differs. Restating an
  inherited value gives `body` a second place to be changed with no second effect: `.data-table td`
  and `th`, `.header-name` and `.stat-value` say nothing about colour; `.stat-label` does.

## Layout

- **A panel header's contents are placed by the band, never by themselves.** Capitals sit high in a
  centred em box, so `.panel-header` is padded 9 over 7 and every child moves with it. Line-height
  can't do this (it is symmetric) and a margin on one child misaligns the rest.
- **The gold line is the panel BODY's `border-top`**, never the header's `border-bottom`, so a shut
  panel draws no line. The chevron turns off `aria-expanded`.
- **Nothing ends a panel on a margin.** `.panel-body :last-child` drops it at any depth; nothing is
  marked last by hand.
- **The phone's fold rules repeat the desktop's `:not(.folds)` selectors**, so they win by order.
- **A table has no minimum width and gives no column a width; its rows decide**, and the leftover is
  shared in proportion to content. A figure never wraps; a name may. A label carrying a unit binds it
  with `&nbsp;`, rendered through `raw/1` because the label is interpolated. Columns stack below
  640px. A wide table may scroll on a phone if what matters most is on the left. Check a table change
  by counting the lines in every cell at every width, not by whether it scrolls.

## Classes

- **A class per thing the game names, never per colour.** `.hp`, `.mp` and `.adena` stay apart even
  where two resolve to one token today, so one can move without the others. They are filed under
  **Values** in `base.css`. Above them, **Utilities** hold what is not a value: `.muted` (something
  that isn't a value standing where one would be, like the `&bull;` between an effect and what it
  does; no weight), `.build-development` and `.build-testing`.
- **A value's class goes where the thing is named in a sentence**, figure or not, and never on a
  label. A value is a classed `<span>`, never a `<strong>`. `legacy/AGENTS.md` has the old game's
  whole vocabulary.
- **A link is underlined, never gold**, because gold is what a run is worth. It is the colour of the
  words around it, on a 1px `currentColor` underline 2px below, and on hover both darken to
  `--text-link`: `currentColor` mixed 77% with black, resolved where it is used, so one rule serves
  prose and alerts alike. The rule never says `:link` or `:visited`, since a `:visited` rule may set
  only colours and would drop the underline. It is `a:where(:not(.btn))`, an element's specificity.
  The banner opts out with `text-decoration: none`; the footer's commit turns gold on hover through a
  transition on `color` alone.
- **A button's focus ring is `currentColor`**, so a new look rings in its own colour.

## Colour

- **Every text colour is a token.** Adding a class means putting it in a group, never inventing a
  hex.
- **A token is named for its role: `--<role>-<name>`.** `--text-`, `--bg-`, `--border-`, `--wash-`,
  `--bar-`, `--glow-`, `--shadow-`, `--focus-`. HP is `--text-hp` in a sentence and `--bar-hp` in a
  meter. Gold is the one exception: the accent is text, border, ground and glow at once. Value
  colours are named for the thing (`--text-hp`, `--text-heal`, `--text-attribute`), alert voices for
  their kind (`--text-danger`, `--text-info`).
- **A new colour is measured, not eyeballed**: 4.5:1 on `--bg-panel`, inside the palette's own
  lightness and chroma, and clear of every other by eye in Lab. Maximising distance alone returns
  neon.
- **Judge colour in CIELCh, never HSL.** HSL saturation is a coordinate, not a quantity: 27% at 8%
  lightness looks neutral and at 40% looks blue.
- **Peers share a lightness, not a chroma.** `--text-hp`, `--text-critical`, `--text-heal`,
  `--text-attribute`, `--text-defense` and `--text-xp` are all `L* 58`, 4.9:1 on the panel. Each runs
  to its own chroma ceiling, capped at 72; a shared chroma would drag them all down to teal's ~39.
- **Seven colours, each worn two to four times.** A blue, a cyan or an indigo beside azure was tried
  and read as one blue; a new value takes an existing colour before it takes a new hue.
- **Stats that come as a pair share a colour, and the name tells them apart**: a P. stat and its M.
  twin, and Accuracy and Evasion, which meet in one roll. Every colour in the Combat Stats sentence
  is a pair.
- **A word and its bar are one hue.** MP is `--text-defense` in a sentence, and its bar is built on
  that hue at sRGB's ceiling rather than the other bars' chroma.
- **An effect's name wears its kind** (`.buff` green, `.debuff` red, and an `.aura`, a state that is
  neither, the sentence's own colour), and so does the glow on its header icon. What it changes wears
  the stat it changes.
- **A panel is held off the page by 7.6 `L*`.** With the chroma gone, that lightness gap is the whole
  separation. Protect it in any restyle.
- **A nested surface lifts off its ground, never sinks into it.** `--panel-lift`, `--table-lift` and
  `--row-lift` are white at three strengths, so a lift works over any ground.
- **JavaScript reads a colour from its token** through `getComputedStyle(document.documentElement)`,
  never a hex copied beside it; the loading bar's copies went stale. `app.js` is deferred, so the
  stylesheet has applied.
- **A mechanical colour transform runs in a single pass.** Build the whole map, then substitute once:
  one hex can be both an input and an output.
- **Moving a ground means re-measuring** everything any comment asserts about it.
