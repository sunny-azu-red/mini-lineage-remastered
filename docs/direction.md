# Mini-Lineage: direction

Why the game is shaped as it is, and the calls already made, so nobody argues them again by
accident. What gets built is [roadmap.md](roadmap.md); where the game departs from Lineage II on
purpose is [canon/README.md](canon/README.md). When this file disagrees with the roadmap, the
roadmap wins, and decisions do get reversed on purpose (classes and the inventory came back on
2026-10-10).

## The objective

**Mini-Lineage is Lineage II (Interlude) made simple: a text-based RPG played in the browser.** It
keeps Lineage II's names, places, monsters and feel, and cuts its systems down to what one player
can read on a page and act on in a click. Canon is where names and starting numbers come from. A
canon particularity is departed from, and the departure written down in
[canon/README.md](canon/README.md), whenever it adds clutter or a choice the player cannot see or
make (2026-10-26). Every call below serves this.

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

- **Read in a table, act through one dropdown.** No button per row (rejected 2026-10-11). A setting (the Battle
  Orders) is the exception: a stepper or a switch, never a dropdown, since it goes nowhere. Over ~15
  rows, a list is split by category. A panel stays uncluttered: SP shows only at the guild and in the Battle Orders' footer, the
  shop never mentions tax, and fewer equipment slots are better than more.

## Balance

Balance matters most, and it is measured, never guessed (AGENTS.md has the bench).

- **The bar**, applied by `bench/compare.exs` (agreed 2026-10-14): no deaths when resting to full;
  no set's time to level 15 moves more than 15%; deaths may not rise past the dice's noise; the
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

- **Adena at ×30, so a character leaves its village in its village's best** (2026-10-29). At ×20 no
  set owned the whole village kit by 15 (the 136,000 weapons and the dearest armour never came); at
  ×30 every path owns it at 14 but the two-handed swords, whose Zweihander is 244,000, and arrives
  in Gludio with 40,000 to 118,000 Adena towards its 244,000 tier and D-grade, which canon's
  Expertise D lets it wear from 20. Prices stay canon: the rate scales every coin alike, Gludio's
  included. Every path reaches 15 1% to 13% sooner, Fighters most, so the spread narrows at three
  settings of four, and deaths fall wherever there were any (resting below half without potions, the
  17 paths from 647 runs of 3,400 to 285). It fails the bar only resting below half with 20 potions,
  the spread widening from 26.1 to 26.7 minutes because the Orc Mystic, the slowest there, gains
  least (1%); without it the spread narrows (21.5 to 21.4). Taken, the Orc Mystic being its own
  work. ×40 was measured too: the kit at 13 to 14, but a Fighter's time moving up to 17%.
- **Balance is measured to level 15, and the village is harder and stops paying at 16**
  (2026-10-29). A character leaves its village for Gludio around 15 or 16, where Gludio's grounds
  open, without a cap telling it to: each starting ground stops at level 14, a hunt meets a monster
  from one level below to one above, and a kill pays half for each level the character stands
  more than one above it (rules §17, §20, departures in `docs/canon/README.md`). The village is
  meant to be harder: resting to full stays safe for every set, but resting below half without
  potions the 17 paths died in 647 runs of 3,400 rather than 159, and the spread to level 15
  (leaving out the Orc Mystic) widened from 27 to 32 minutes resting to full and from 26 to 36
  below half, past the bar, which the game takes. The Human Mystic is fastest, and the Elven
  Fighter, Dark Fighter, Dark Mystic and both Orcs are the work this leaves (`docs/balance.md`).
  Gludio has to pay more than a village ground a character has outgrown, measured when it is built.

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
- **The Orc Mystic is the slowest set, by about 100 minutes** (2026-10-19). Deferred, not
  forgotten. It reaches 20 in 272 minutes resting to full, against 169 for the Elven Mystic and 175
  for the Human: fights of 11.5 rounds against 6.5 to 6.8, and 123 minutes fighting and 149
  resting against 74 and 94. What the bench has shown so far (`docs/balance.md`):
  - It has no Wind Strike, so it opens with Chill Flame, a 5.1-second cast (the slowest Casting
    Spd., from its WIT) whose burn deals a fixed amount over 15 seconds, so neither M. Atk. nor
    Weapon Mastery speeds it up much (1% to 3% from the masteries, where the other sets gained 5% to
    16%).
  - Chill Flame is not cast again while the monster still burns, and Life Drain waits until the Orc
    Mystic is below 85% of its HP, so it often has nothing to cast while the monster comes at it.
  - Its levers already measured: Life Drain below 70% instead was 13% to 15% faster but doubled
    its deaths without potions; Soul Cry left unused saves about 9%.

  Unmeasured candidates: a burn that grows with M. Atk., a Life Drain threshold between 70% and 85%, its ground's
  monsters. None of them has been tried yet.
- **One heal a set, and every skill on a switch** (2026-10-26). The Elven Mystic learns Heal from
  level 1 and never Self Heal: the two had cast in turn on two reuses the player could neither see
  nor order, and dropping one moved the set by 0.1% at most and killed no run. Every heal wears
  💚, as the Mend orders do. Every skill but a mastery takes a switch in the Battle Orders, the heal
  and Relax included, so the player decides each one.
- **A shield never turns a spell** (L2J, 40c2446): an item reading "Shield P. Def." should not raise
  M. Def.
