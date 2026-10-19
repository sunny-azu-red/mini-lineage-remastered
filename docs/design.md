# Design

How the game is drawn. What a control IS lives in `AGENTS.md`; this is how it looks. Each rule here
was got wrong once.

## Type

- **Size is hierarchy, never container.** 13px is anything read: prose, an alert, a table cell, a
  sidebar value. 12px is a control, and a shelf's heading row. 11px is a label (a column's, a
  field's, a log entry's head), set by one rule in `base.css` at weight 600, 0.1em, in capitals; the footer, the level
  badge and the banner's subtitle are 11px too, each set where it stands. The exceptions are 10px
  for the figures and labels inside the HP, MP and XP bars, because an 18px bar has no room, the 8px
  effect badge below, and the banner's 26px title. A field label's 1px
  `margin-top` is optical: `text-box-trim` is missing from Firefox.
- **The sidebar is 210px.** Widen it before shrinking a value, and never without asking.
- **A heading takes no size or weight from the browser**, only from its class.
- **Weight answers "which of these matters?", so a table never needs it.** Tabular figures are on
  `body`, so columns line up and a counting number doesn't reflow its line. Weight is scoped to
  values inside `p` and `li`, as one `:is(p, li) :is(…)` list, so adding a name is one edit. Only
  Inter 400, 500 and 600 are loaded; 700 is faked.
- **An effect's time left is legacy's badge**: Silkscreen (`--font-pixel`) at 8px, centred over the
  header icon and outlined in black, in its kind's colour. It sets its own case and colour, or it
  takes the band's gold capitals ("1M"), and it sits over the icon because beside it the row of
  icons would widen every second.
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
- **A list is spaced by its gap, never by line-height.** A `.stat-row.stacked` keeps every line at
  line-height 1, as every other row does; leading added to some lines spaces the panel unevenly. A
  link's underline would need that room, so a list holds none: a panel's way somewhere is one
  link of its own, on its own row or ending one (the Inventory's Open, beside the purse).
- **A log is legacy's Chronicle**: an entry a row, ruled as the sidebar's rows are, its head a
  label (when on the left, where both sides stand on the right, each side's HP as a percent) over
  the line, muted throughout, delimiter included. A row is washed, in the colour and fade of the
  alert that would have said it, for how the fight opened (an Encounter info, an Ambush danger),
  for a critical hit on either side (`--wash-critical`, the orange a critical is written in), else
  for HP either side mended (success: a heal, a potion, a drain), and for how it ended (Victory and
  Escaped both info, green being the mend's). Every other row keeps the panel's ground, and in a
  death's alert, the alert being the ground, none is washed.
- **A panel of settings is three columns shared down its rows** (subgrid): an 11px label, the
  control, then what it is set to, right-aligned. That last column is a fixed 9em, the widest value
  with room: sized to its content, it resized the track under a drag. A stepper's
  track, fill and stop dots run between the thumb's centre at either end, where a native range puts
  each step, and are drawn under the input, which keeps only its thumb: gold, ringed in the panel's
  ground. The fill is `--gold-dim`, the stops it reaches `--gold`: a red track outshouted
  everything near it, so only the share's figure is HP's red, and "never" is the sentence's own
  colour. Switches sit beside their label in equal columns (10.5em, the longest name), on the row's
  own ground with no border: each the skill's emoji and name, then a 22px track ending the column,
  so the tracks line up. On, the track is green, as gold is the name's; off, the track and the name
  mute, and a hover rings the track and lifts its knob. The track follows the name because before
  it, beside the emoji, the two marks crowded. The last row is a footer, as the Inventory's purse
  row is: SP on the left in `.sp`, with no emoji (📖 is the guild's), and 🧹 Reset to Default on
  the right, a `.link-button` drawn as Open is, and disabled at the defaults: muted, with no
  underline. A control that comes and goes beside a figure is disabled, never swapped for text,
  since the swap rebuilds the row and the figure beside it blinks. On a phone a label takes the line above its
  control, the switches included.
- **Nothing ends a panel on a margin.** `.panel-body :last-child` drops it at any depth; nothing is
  marked last by hand.
- **The phone's fold rules repeat the desktop's `:not(.folds)` selectors**, so they win by order.
- **A table has no minimum width and gives no column a width; its rows decide**, and the leftover is
  shared in proportion to content. A figure never wraps; a name may, and an item's name carries its
  stats after a `.delimiter` bullet rather than in a column of their own. A label carrying a unit
  binds it with `&nbsp;`, rendered through `raw/1` because the label is interpolated. Below 520px a
  column's label may take two lines; the page's layout and the inventory's columns stack below
  640px. A wide table may scroll on a phone if what matters most is on the left. Check a table change
  by counting the lines in every cell at every width, not by whether it scrolls.

## Classes

- **A class per thing the game names, never per colour.** `.adena`, `.level` and `.skill` stay apart
  though all three resolve to gold today, so one can move without the others. They are filed under
  **Values** in `base.css`. Above them, **Utilities** hold what is not a value: `.muted` (something
  that isn't a value standing where one would be; no weight), `.delimiter` (the `&bull;` between a
  name and what it does, a skill's, an effect's or an item's, one step brighter than muted so it
  stands apart from an item's muted stats too; between two muted sides, as in a log's head, it has
  nothing to stand apart from and inherits their muted colour), `.timer` (an effect's time left, dimmed like a date),
  `.build-development` and `.build-testing`.
- **A value's class goes where the thing is named in a sentence**, figure or not, and never on a
  label. A value is a classed `<span>`, never a `<strong>`. `legacy/AGENTS.md` has the old game's
  whole vocabulary.
- **A link is underlined, never gold**, because gold is what a run is worth. It is the colour of the
  words around it, on a 1px `currentColor` underline 2px below, and on hover both darken to
  `--text-link`: `currentColor` mixed 77% with black, resolved where it is used, so one rule serves
  prose and alerts alike. The rule never says `:link` or `:visited`, since a `:visited` rule may set
  only colours and would drop the underline. It is `a:where(:not(.btn))`, an element's specificity,
  and `.link-button`, a button standing where a link would, shares the selector so the two never
  drift.
  The banner opts out with `text-decoration: none`; the footer's commit turns gold on hover through a
  transition on `color` alone.
- **A button's focus ring is `currentColor`**, so a new look rings in its own colour.

## Motion

- **What moves near text moves by a painted property.** An animated `transform`, `opacity` or
  `filter` is composited, and Chrome lifts everything painted after it inside its nearest clip (a
  `.panel`, being `overflow: hidden`) onto layers that lose their LCD text: the text blinks for the
  run, and a headless browser never shows it. So the switch's knob slides by `left` and a button's
  shimmer sweeps by `left` and fades by a registered `--shimmer`. Where only a composited property
  will do (an effect icon's fade), it runs inside an `overflow: clip` of its own, with
  `overflow-clip-margin` for what spills, and never fills `forwards`, which keeps a finished
  animation running to the compositor. A shine laid OVER its text (the triumph alert's) lifts
  nothing that matters. The walkthrough's `lifted()` reads the layer tree to hold each of these.

## Colour

- **Every text colour is a token.** Adding a class means putting it in a group, never inventing a
  hex.
- **A token is named for its role: `--<role>-<name>`.** `--text-`, `--bg-`, `--border-`, `--wash-`,
  `--bar-`, `--glow-`, `--shadow-`, `--focus-`. HP is `--text-hp` in a sentence and `--bar-hp` in a
  meter. Gold is one exception: the accent is text, border, ground and glow at once. The lifts are
  the other, named for the surface they raise (`--panel-lift`). Value colours are named for the thing
  (`--text-hp`, `--text-heal`, `--text-attribute`), alert voices for their kind (`--text-info`,
  `--text-success`, `--text-triumph`, `--text-danger`). Success borrows its edge and wash from
  `--text-heal`; triumph speaks gold on `--gold`.
- **A new colour is measured, not eyeballed**: 4.5:1 on `--bg-panel`, inside the palette's own
  lightness and chroma, and clear of every other by eye in Lab. Maximising distance alone returns
  neon.
- **Judge colour in CIELCh, never HSL.** HSL saturation is a coordinate, not a quantity: 27% at 8%
  lightness looks neutral and at 40% looks blue.
- **Peers share a lightness, not a chroma.** `--text-hp`, `--text-critical`, `--text-heal`,
  `--text-attribute`, `--text-defense` and `--text-xp` are all `L* 58`, 4.9:1 on the panel. Each runs
  to its own chroma ceiling, capped at 72; a shared chroma would drag them all down to teal's ~39.
- **Seven value colours, each worn two to four times**, the six peers and gold. The four alert
  voices stand apart: danger, success and info share one lightness (6.7:1 on the panel), and
  triumph's gold is lighter (9.6:1). A blue, a cyan or an indigo beside azure was tried
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
