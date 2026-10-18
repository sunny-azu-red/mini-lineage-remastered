# Mini-Lineage: direction

Why the game is shaped as it is, and the calls already made, so nobody argues them again by
accident. What gets built is [roadmap.md](roadmap.md); where the game departs from Lineage II on
purpose is [canon/README.md](canon/README.md). When this file disagrees with the roadmap, the
roadmap wins, and decisions do get reversed on purpose (classes and the inventory came back on
2026-10-10).

## What the game is for

- **Nostalgia, not simulation.** Real Interlude (C6) names, places, monsters and items bring Lineage
  II back; the systems are cut down so the game stays fun. "Mini" is the point: no big skill trees,
  no slot for everything, no ground for everything. Fun and feel beat canon (2026-10-13): canon is
  where names and starting numbers come from, never a reason to keep clutter, so nine trainer lines
  for one skill become tiers. Use the full iconic names; the IP question is settled.
- **A web game replayed for a highscore, not an MMO.** That is why death is final (2026-10-10): the
  run ends and its row stays in the Halls. Lineage II's EXP-loss death is not coming back.
- **A new player understands the first click**: spawn, one-click hunt, Adena, buy, move on to
  Gludio. Complexity (rounds, choices, skills in use) belongs to bosses and dungeons, up to
  Antharas.
- **The hunt stays instant and shows its own clock** (2026-10-19). Each round of the log says when it
  starts, so a skill's "Reuse 10.4s." can be read off it. Time inside a fight is the fight's, in a
  hunt and in a boss fight alike, however long the player takes over a round, so a skill's times mean
  the same in both.
- **Every place keeps a reason to visit** once its grounds are outlevelled: the home village teaches
  skills and changes class, towns sell buffs and better gear, player shops sell every shot.
- **A village ground is one ladder under one nostalgic name** (Obelisk of Victory, Elven Fortress,
  School of Dark Arts, Cave of Trials), pooling the village's canon monsters at their own levels.
  The evocative name won over level fidelity.

## The sets

- **Each race feels different**, down to the first skill: "Power Shot for three of the races won't
  cut it" (2026-10-11).
- **Sets do not play alike, and some are stronger than others.** "Classes are different play
  styles, normal for a healthy game" (2026-10-13). No shared role template (every set gets a guard,
  every set a recovery). The identity departures stay: the Elven Fighter has Defense Aura only, the
  Dark Fighter Attack Aura only, Relax is the Orc Fighter's alone, and the Human Fighter is the
  all-round weapon user. A gap is filled from the set's own canon tree.

## Consistency

- **One spelling across the game beats a canon quirk** ("i like consistency better than canon",
  2026-10-15). When Lineage II names one kind of thing two ways (Warrior Guild, Warriors' Guild),
  the game uses one form, apostrophes dropped, listed as a departure in `canon/README.md`. Proper
  names stay as canon has them (Eva's Sanctuary, Temple of Shilen). One mismatch found means
  sweeping for its kind and proposing a rule, never a one-off fix: that is how AGENTS.md's "Prose and
  markup" came about.

## The screens

- **Read in a table, act through one dropdown.** No button per row (rejected 2026-10-11). Over ~15
  rows, a list is split by category. A panel stays uncluttered: SP shows only at the trainer, the
  shop never mentions tax, and fewer equipment slots are better than more.

## Balance

Balance matters most, and it is measured, never guessed (AGENTS.md has the bench).

- **The bar**, applied by `bench/compare.exs` (agreed 2026-10-14): no deaths when resting to full;
  no set's time to level 20 moves more than 15%; deaths may not rise past the dice's noise; the
  spread between sets may not widen (2% tolerance). Time is compared run for run, over runs that
  finished in both readings.
- **A change that fails the bar is reported, not tuned quietly.** The owner decides, and has
  accepted a deliberate gap before (Mystics faster at range) when it fits the design.
- **How a change is measured** (the baseline worktree, the matrix, the compare) is the
  `balance-study` skill in `.claude/skills/`.
- **The bench plays the meta** ("simulate realistic gameplay, and flag odd builds that break the
  game", 2026-10-17). Off-meta rows are flagged, never held to the bar. Canon is preferred over a
  departure where the bench allows it: aCis's shield block won whole over L2J's ×1.3 against arrows.

### Calls already made

- **Piece pricing stays despite the Dark Mystic** (6a43a98, 2026-10-16). Pricing every chest, legs
  and necklace by what it stands for failed the risky-play bar (resting below half, no potions): the
  Dark Mystic two-hander went from 7 to 81 deaths in 400. The masteries brought it to 2 / 6 of 200
  (one-hander / two-hander). What is left is the Balor Orc Fighter at level 10, and the lever named
  for it is the Dark Elf ground's melee monsters at 10 to 13, not prices. Deferred, not forgotten.
- **Three masteries a path, for every set, and the player's choice** (Armor or Robe Mastery, Weapon
  Mastery, Anti Magic; 182d8b8, 87027a5, 2026-10-17). Weapon Mastery and Anti Magic made every set 2
  to 15% faster to 20, past the 15% bar on the Dark Mystic two-hander, accepted for the faster road.
  Anti Magic is judged by the casters of the grounds to come (Gludio, Dion, Giran), not today's, so a
  set that dies more for learning it early (the Human Fighter with a bow) is acceptable. Every line
  past level 1 is at canon's price.
- **Fighter Anti Magic and non-Orc Robe Mastery stay** (2026-10-18): removing Fighter Anti Magic for
  canon fails the bar on the Orc Fighter against the Evil Eyes, and Robe Mastery is the owner's call.
- **Casts and reuses keep the rest of a round, past the bar** (2026-10-19). One ending partway
  through a round no longer rounds up to the next, so Casting Spd. counts as it does in Lineage II.
  The Elven Mystic, the fastest caster, reaches 20 12% to 16% sooner (past 15% resting below half)
  and becomes the fastest set, the Human Mystic 4% to 7%, everything else under 2%, and the spread
  from the fastest set to the slowest widens from 92 to 103 minutes resting to full. Accepted: the
  Elf's speed is the point of the set. The slow end is the Orc Mystic's to fix, never the clock.
- **A shield never turns a spell** (L2J, 40c2446): an item reading "Shield P. Def." should not raise
  M. Def.
