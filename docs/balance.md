# Mini-Lineage: balance, measured

What the village ladder costs and pays, read off `bench/ladder.exs`. The rules (`docs/rules.md`) say
what things cost; this says when a player can afford them. Every figure here was measured, never
worked out by hand, and holds only for the rules it was measured against.

**Measured** at rules §22's private rates (EXP and SP ×5, Adena ×30, from `.env.test`), on rules
§1 to §26 as they now stand: the fight of §20 on a line between the two, spells that take effect
as their cast ends and strike nothing once the monster has fallen, casts and reuses that keep what
is left of the round they end in, the battle orders (every skill but a mastery on a switch, and one
heal a set, the Elven Mystic's Heal from level 1), and the first skills (a Fighter's weapon
skills from level 1, where Lineage II taught them at 5, and Wind Strike for every Mystic but the
Orc), Life Drain cast as
a heal, the Evil Eyes choosing their spell by distance, and auras that hold 2 minutes, raised before
the pull, each fighter's kit a Squire's weapon for every path its skills take, the Orc Mystic's an
Apprentice's Wand, each path shown only its own goods, one of each kind per price, every chest,
legs and necklace priced as many of its slot as it stands for, and three masteries on every path,
Armor Mastery for a Fighter and Robe Mastery for every Mystic, and Weapon Mastery and Anti Magic for
both, each multiplying before it adds as Lineage II does, every line at Lineage II's price but
level 1's, and every shield blocking at 20 and costing 8 Evasion, as all of Lineage II's do, and
catching as aCis's do: three times as often against an arrow or a critical, and five blows in a
hundred perfectly, and the character's own order of casts: of two spells as strong the cheaper
first, a shackle on a monster with no spells once it has run in, and Curse: Poison ticking every
second and able to kill, laid first on a monster that is not aggressive; and, since 2026-10-29,
each village's ground stopping at level 14, a hunt meeting a monster from one level below the
character to one above, and a kill paying half for each level past one below (rules §17, §20). One
`--final` reading of that build, 200 seeded runs of every set up its village's ladder to level 15,
where a character leaves for Gludio, once per weapon path its skills can use, each run seeded on its
own; at the defaults none of them died. The sections after "Level 15" were measured to level 20
on the rules before that, and say so. The bench learns every line its weapon uses and every mastery, which a player need not.

**Rerun it** after anything that moves a fight's numbers, a price, a monster's SP or Adena, or the
trainer's list, and rewrite these tables from what it prints (seconds, its runs in parallel):

    MIX_ENV=test mix run --no-start bench/ladder.exs [runs] [top level] [rest below %] [potions kept]
      [--json path] [--only "Set name,Set name"] [--orders <pull share>,<fight share>]
      [--unused "Skill,Skill"]
    MIX_ENV=test mix run --no-start bench/ladder.exs --matrix <path prefix> [--final] [runs] [top level]
      [--only "Set name,Set name"] ...

`--matrix` takes the study's readings in one go, 200 runs a path unless told otherwise, each into
`<prefix>_<setting>.txt` and `.json`: `defaults` (resting to full, 20 potions), `harsh` (resting
below half, none) and `potions` (below half, 20), and with `--final` `harsher` (below 30%, none) as
well, which most Fighters do not survive and so is kept for the reading these tables come from. The
whole `--final` matrix takes about 3 minutes on 8 cores with the off-meta builds, a routine one about two,
and `--only` one set a fraction of that: no set's runs read another's, so a change to one set is
benched alone.
At 200 runs a time change lands within half a point of what 400 measure.

Each run's dice are seeded from its set and number, so a change moves only the runs it touches. To
judge a change, take a reading on the build before it (a `git worktree`) and one after with the
same settings and runs, and read them with `bench/compare.exs before.json after.json`, which holds them
to the bar: no deaths when resting to full, no set's road to the top moving more than 15%, deaths
not rising past the dice's noise, and the spread between sets not widening. Time is compared run for
run, over the runs that reached the top in both readings, so runs a change saves from dying do not
move a set's figure.

**How the bench plays**, as a player would, at its defaults: it rests to full before every hunt
and keeps 20 Lesser Healing Potions. It learns every line the trainer offers as soon as it can pay
for it, but a weapon skill only for its own weapon: a dagger's run buys no Power Strike. At the shop
it buys the best upgrade it can afford in each slot, weapon first, and sells back the piece it
replaced. A path is a weapon type and the hands it is held in. A sword or a staff in one hand goes
with a shield and a dagger without, since a shield's 8 Evasion is what a dagger fights with. A
two-handed path holds one-handers, with a shield, only until its first two-hander is affordable,
then skips straight to the two-handers (the Zweihander path never buys a Long Sword).

**Off-meta builds** are run beside the paths and flagged when they beat them (see the last section):
each one-handed path again with the other shield choice, on the same dice so the two compare run for
run. `compare.exs` shows them but holds only the paths to the bar.

## Level 15: the village, as it now stands

A character leaves its village for Gludio at about 15 (`docs/direction.md`). Its ground stops at
level 14 and pays half for each level the character stands more than one above a monster, so 15 to
16 still pays in full and the village stops being worth it after. Adena runs at ×30 (rules §22),
so a character leaves wearing the best its village sells. Minutes to 15, with deaths in 200 runs a
path, at each of the bench's settings:

| Set | Path | Resting to full, 20 potions | Of it resting | Behind the fastest | Below half, no potions | Below 30%, no potions | Below half, 20 potions |
|---|---|---|---|---|---|---|---|
| Human Mystic | staff 1h / 2h | 62 / 62 | 36 / 37 | +0% / +0% | 55 / 55 (0 / 0 died) | 54 / 54 (0 / 0) | 54 / 54 (0 / 0) |
| Elven Mystic | staff 1h / 2h | 69 / 68 | 36 / 36 | +11% / +10% | 63 / 62 (0 / 0) | 63 / 62 (0 / 0) | 63 / 61 (0 / 0) |
| Human Fighter | sword 1h / 2h / dagger / bow | 70 / 70 / 69 / 70 | 37 to 38 | +12% to +14% | 64 to 65 (1 / 0 / 36 / 5) | 61 to 62 (94 / 85 / 164 / 58) | 58 to 62 (0 / 0 / 1 / 0) |
| Elven Fighter | bow | 82 | 38 | +33% | 78 (65) | 76 (190) | 70 (0) |
| Dark Fighter | dagger | 85 | 51 | +36% | 79 (58) | 76 (188) | 65 (0) |
| Dark Mystic | staff 1h / 2h | 91 / 87 | 55 / 52 | +47% / +41% | 85 / 81 (13 / 21) | 84 / 79 (17 / 34) | 76 / 72 (0 / 0) |
| Orc Fighter | fists / sword 1h / 2h | 85 / 87 / 87 | 51 to 52 | +37% to +41% | 79 to 82 (12 / 40 / 34) | 76 to 80 (180 / 189 / 176) | 69 to 73 (0 / 1 / 0) |
| Orc Mystic | staff 1h / 2h | 90 / 90 | 47 / 47 | +46% / +45% | 81 / 81 (0 / 0) | 76 / 76 (14 / 15) | 81 / 81 (0 / 0) |

Minutes for each level past 15 resting to full, read at tops 16 to 18 with Adena at ×20, are 13
to 35 for 15 to 16, 31 to 73 for 16 to 17 and 54 to 164 for 17 to 18: the second about twice the
first, the third four to six times. What a set has at 15, and when its gear comes:

| Set | Hunts to 15 | SP held at 15 | Whole village kit owned at | Adena held at 15 |
|---|---|---|---|---|
| Human Fighter | 122 | 2,967 to 3,020 | 14 (sword 2h never) | 102k to 112k |
| Human Mystic | 122 | 788 to 795 | 14 | 85k |
| Elven Fighter | 151 | 3,239 | 14 | 79k |
| Elven Mystic | 151 | 252 to 255 | 14 | 40k to 101k |
| Dark Fighter | 145 | 2,430 | 14 | 78k |
| Dark Mystic | 145 | 196 to 197 | 14 | 49k to 105k |
| Orc Fighter | 130 to 131 | 2,282 to 2,342 | 14 (sword 2h never) | 100k to 118k |
| Orc Mystic | 131 | 1,332 to 1,334 | 14 | 70k to 93k |

- **The Human and Elven Mystics set the pace,** and the Human Mystic is fastest. Talking Island's
  Stone Golem and Crasher at 13 and 14 pay the most EXP a hunt, so its sets need 122 hunts to 15
  where the Orc ground asks 131, the Dark Elf one 145 and the Elven one 151.
- **Everyone else is 10% to 47% behind,** and that is the work this leaves: the Elven Fighter at
  +33%, the Dark Fighter at +36%, the Orc Fighter at +37% to +41%, the Dark Mystic at +41% to +47%
  and the Orc Mystic at +45% to +46%. The Dark Elves and Orcs rest most, 47 to 55 minutes of their
  85 to 91.
- **Resting to full is safe; a careless rest is not.** No set dies resting to full. Below half
  without potions the Fighters and the Dark Mystic die in 1 to 65 runs of 200, and below 30% the
  Fighters in 58 to 190. The Human and Elven Mystics survive both, and the Orc Mystic dies only
  below 30% (14 to 15). Twenty potions bring every path back to 0 or 1.
- **Every path leaves in its village's best,** the 136,000 weapon and the dearest armour,
  necklace and shield all owned at 14, but the two-handed swords, whose Zweihander (244,000) is
  still out of reach. Tiers come at about 4, 9 and 13: 768 at 4.0 to 4.3, 12,500 at 8.3 to 9.1,
  54,100 at 12.6 to 13.2 (the Mystic one-hander's line has no 54,100 piece and goes from 12,500 to
  136,000 at 14).
- **Each path reaches 15 with 40,000 to 118,000 Adena,** having earned 289,000 to 319,000, towards
  Gludio's 244,000 tier and D-grade. The lessons are still out of reach: a Fighter reaches 15 with
  2,300 to 3,200 SP against 3,300 to 4,000 for each of its five level-15 lines, a Mystic with 200
  to 1,300 and nothing left to learn.
- **Adena at ×30 rather than ×20** made every path 1% to 13% faster, Fighters most (their weapon
  and armour come two tiers sooner), and cut deaths below half without potions from 647 runs of
  3,400 to 285. The spread from the fastest set to the slowest narrowed at three settings and widened
  at the fourth (below half, 20 potions, 26.1 to 26.7 minutes) only through the Orc Mystic, which
  gains 1%.

## Before the move to 15: the road to 20

Measured to level 20 under the earlier rules and Adena at ×20, every ground's whole roster, a hunt meeting a
monster from three levels below up to its own, and the reward shrinking by 5/6 a level past the
fifth. Kept for what it found about the trainer, the shop, the sets and what was tried; the section
above wins wherever the two disagree.

### The trainer: SP

Every set earns about **32,500 SP** from level 1 to 20, and three quarters of it comes after level 15.
SP doesn't depend on the weapon path, and only the Human and Orc Fighters' lists do, since only they
have a weapon skill for more than one path.

| Set | Skills (lines) | Whole list | Of it, Weapon Mastery and Anti Magic | Learned at level | …at hunt | SP saved at 20 |
|---|---|---|---|---|---|---|
| Human Fighter, sword | 4 (12) | 18,310 | 7,940 | 17 | 232 of 347 | 14,200 |
| Human Fighter, dagger or bow | 4 (12) | 18,360 | 7,940 | 17 | 233 of 347 | 14,200 |
| Elven Fighter | 6 (14) | 19,360 | 7,090 | 17 | 290 of 414 | 13,600 |
| Dark Fighter | 6 (14) | 18,120 | 6,650 | 17 | 273 of 395 | 14,800 |
| Orc Fighter, fists | 5 (13) | 18,930 | 7,770 | 17 | 260 of 385 | 13,900 |
| Orc Fighter, sword | 5 (13) | 18,990 | 7,770 | 17 | 260 of 385 | 13,900 |
| Human Mystic | 6 (12) | 12,940 | 5,250 | 16 | 190 of 347 | 19,600 |
| Elven Mystic | 6 (14) | 15,550 | 5,340 | 16 | 251 of 414 | 17,400 |
| Dark Mystic | 9 (14) | 15,500 | 5,250 | 16 | 245 of 395 | 17,400 |
| Orc Mystic | 7 (13) | 13,370 | 4,600 | 16 | 205 of 385 | 19,500 |

A tier's lines are taught at one character level (1, 5, 10 and 15 for a Fighter; 1, 7 and 14 for a
Mystic), and no two lines of one skill share one. The wait is how many hunts pass between reaching
that level and buying a line taught there, shown as average / worst:

| Set | Level 1 | First tier | Second | Third |
|---|---|---|---|---|
| Human Fighter, sword | | L5: 12 / 33 | L10: 39 / 78 | L15: 45 / 81 |
| Human Fighter, dagger or bow | 5 / 5 | L5: 14 / 34 | L10: 40 / 79 | L15: 46 / 82 |
| Elven Fighter | | L5: 16 / 39 | L10: 40 / 84 | L15: 63 / 120 |
| Dark Fighter | | L5: 13 / 33 | L10: 41 / 89 | L15: 58 / 109 |
| Orc Fighter, fists | | L5: 18 / 42 | L10: 52 / 88 | L15: 61 / 105 |
| Orc Fighter, sword | 6 / 6 | L5: 20 / 44 | L10: 53 / 90 | L15: 61 / 106 |
| Human Mystic | 5 / 5 | L7: 29 / 54 | L14: 24 / 65 | |
| Elven Mystic | 5 / 5 | L7: 33 / 63 | L14: 50 / 117 | |
| Dark Mystic | 5 / 5 | L7: 33 / 62 | L14: 49 / 113 | |
| Orc Mystic | 5 / 5 | L7: 33 / 58 | L14: 30 / 77 | |

- **Every set starts knowing its first skill,** a Fighter the one its starting weapon uses, and a
  Mystic, a Human Fighter with a dagger or a bow and an Orc Fighter with a sword find something at
  the trainer at level 1, bought after 5 or 6 hunts: Self Heal, the Elf's Heal or Soul Cry, Mortal Blow or Power
  Shot, Power Strike. Moving a Fighter's first skill from 5 to 1 changed no set by more than
  1.4%; a Mystic made to buy its first spell instead died at levels 1 to 3 in nine runs of ten.
- **No tier is empty, and every set can afford its whole list.** Each tier's first line can be bought
  on arrival, and every tier past level 1 offers four to six lines, two or three of them masteries,
  so the player chooses the order.
- **The masteries are bought after the skills they fight with,** from what is left: the bench buys
  a tier's lines in the trainer's order, the masteries last (Armor or Robe Mastery, then Weapon
  Mastery, then Anti Magic), so they stretch the list rather than delay a skill. Weapon Mastery and
  Anti Magic cost 4,600 to 7,940 SP a set, and every tier waits longer: at the last tier 23 to 63
  hunts on average, where it was 27 to 49.
- **Robe Mastery costs every Mystic the Orc Mystic's canon 520 and 1,760.** Its second line was
  6,800, so that a Mystic reached 20 with what an Elven or Dark Fighter has left; measured on this
  build at 1,760, 5,000, 6,800 and 8,500, its price moved no Mystic's time by more than 0.6% and no
  death past the dice's noise, only the SP at 20 (17,200 to 19,600 at canon, 12,200 to 14,600 at
  6,800) and when the list is done (hunts 190 to 253 at canon, 229 to 304 at 6,800).
- **The late lines cost what Lineage II asks,** where the Elven and Dark Fighters' at 15 and the
  Human, Dark and Orc Mystics' at 14 cost 1,350 to 4,250 SP more a set to soak up the SP of the
  masteries then left out. Back at canon, those five sets finish their lists up to a level sooner
  and keep that SP; the Elven Fighter is 2% faster and resting at half without potions it dies in
  34 runs of 200 rather than 49, and the Dark Fighter in 14 rather than 24. The Orc Mystic is 0.6% to
  1.7% slower for it, most likely for buying Soul Cry 2, whose MP drain costs it time, sooner, and
  the spread from the fastest set to the slowest widens by 1 to 4 minutes, which the game takes.
- **Every list is learned at 16 to 17,** a Mystic's at 16 to 17 and every Fighter's at 17: a
  Mystic's masteries hold two lines to a Fighter's three, and its fights spend MP rather than SP.
- **A Fighter buys only its own weapon's line,** as a player who stays with one weapon does. The
  Human Fighter, buying all three of its weapon lines, paid 28,630 and finished at level 19 with
  3,900 SP to spare; the Orc Fighter, buying both, paid 24,390 and finished at 18. Each now pays
  about 18,300 to 19,000 like every other Fighter, and its third tier waits 45 to 61 hunts rather
  than 96 or 97.
- **From the end of the list to level 20, the trainer has nothing left to sell.** That is 115 to 180
  hunts while SP builds up for the class change: 17,400 to 19,600 for a Mystic and 13,600 to 14,800
  for a Fighter (11,900 to 17,700 for every set before Weapon Mastery and Anti Magic). A first tier
  of class-change skills is best priced per class against these, what a set that learned everything
  can afford on reaching 20; one that skipped a mastery has more.

### The shop: Adena

Gross Adena earned from monsters, by the level reached. Each figure is the range across sets.
Talking Island sits at the low end from level 16, because its ground tops out at level 17.

| Level | 5 | 10 | 12 | 14 | 15 | 16 | 17 | 18 | 20 |
|---|---|---|---|---|---|---|---|---|---|
| Earned | 2k | 32–33k | 77–79k | 152–159k | 201–214k | 258–280k | 321–353k | 400–438k | 616–647k |

The best kit each path can buy in its village, priced in rules §24. Armour is the best chest and legs
plus the Necklace of Wisdom, each priced as many of its slot as it stands for: 88,567 in light armour
(Bone Breastplate 33,397, Bone Gaiters 17,639, the necklace 37,531) and 108,711 in robes (Tunic of
Devotion 47,367, Stockings of Devotion 23,813), where both were 44,900 at canon's prices.

| Path | Weapon | Shield | Whole kit |
|---|---|---|---|
| Sword 1h | Long Sword 136,000 | Round Shield 7,110 | 231,677 |
| Sword 2h | Zweihander 244,000 | | 332,567 |
| Dagger | Throwing Knife 136,000 | | 224,567 |
| Bow | Forest Bow 136,000 | | 224,567 |
| Fists (Orc Village) | Cestus 136,000 | | 224,567 |
| Staff 1h | Relic of The Saints 136,000 | Round Shield 7,110 | 251,821 |
| Staff 2h | Journeyman's Staff 136,000 | | 244,711 |

The level each of a path's weapons is first held at, then the level and hunt the whole kit is worn
(the weapon is always the last piece bought), then the Adena still held at level 20:

| Set | Skill | Path | 768 | 12,500 | 54,100 | Top weapon, kit | Hunt | Held at 20 |
|---|---|---|---|---|---|---|---|---|
| Human Fighter | Power Strike | sword 1h | Short Sword 4.3 | Broadsword 10.0 | Gladius 14.1 | Long Sword **16.4** (16–17) | 210 | 327k |
| Human Fighter | Power Strike | sword 2h | Short Sword 4.4 | Broadsword 10.0 | Brandish 14.2 | Zweihander **17.9** (17–18) | 260 | 222k |
| Human Fighter | Mortal Blow | dagger | Bone Dagger 4.1 | Knife 9.3 | Dirk 14.0 | Throwing Knife **16.3** (16–17) | 206 | 337k |
| Human Fighter | Power Shot | bow | Short Bow 4.0 | Bow 9.3 | Hunting Bow 14.1 | Forest Bow **16.3** (16–17) | 207 | 332k |
| Elven Fighter | Power Shot | bow | Short Bow 4.2 | Bow 9.4 | Hunting Bow 14.0 | Forest Bow **16.0** (15–17) | 234 | 362k |
| Dark Fighter | Mortal Blow | dagger | Bone Dagger 4.3 | Knife 9.5 | Dirk 14.0 | Throwing Knife **16.0** (15–16) | 225 | 341k |
| Orc Fighter | Iron Punch | fists | Spiked Gloves 4.2 | Iron Gloves 9.4 | Fox Claw Gloves 14.0 | Cestus **16.1** (16–17) | 216 | 340k |
| Orc Fighter | Power Strike | sword 1h | Short Sword 4.5 | Broadsword 10.0 | Gladius 14.2 | Long Sword **16.2** (16–17) | 221 | 331k |
| Orc Fighter | Power Strike | sword 2h | Short Sword 4.5 | Broadsword 10.0 | Brandish 14.2 | Zweihander **17.7** (17–18) | 278 | 227k |
| Human Mystic | | staff 1h | Horn 4.3 | Scholar's Tome 10.1 | | Relic **16.1** (16–17) | 200 | 329k |
| Human Mystic | | staff 2h | Horn 4.4 | Willow Staff 10.1 | Cedar Staff 14.8 | Journeyman's **16.9** (16–18) | 220 | 304k |
| Elven Mystic | | staff 1h | Horn 4.6 | Scholar's Tome 10.1 | | Relic **16.0** (15–16) | 225 | 357k |
| Elven Mystic | | staff 2h | Horn 4.6 | Willow Staff 10.1 | Cedar Staff 14.6 | Journeyman's **16.4** (16–17) | 250 | 334k |
| Dark Mystic | | staff 1h | Horn 4.7 | Scholar's Tome 10.2 | | Relic **15.9** (15–16) | 216 | 337k |
| Dark Mystic | | staff 2h | Horn 4.6 | Willow Staff 10.1 | Cedar Staff 14.4 | Journeyman's **16.3** (16–17) | 240 | 315k |
| Orc Mystic | | staff 1h | Horn 4.5 | Scholar's Tome 10.1 | | Relic **16.0** (16–17) | 210 | 334k |
| Orc Mystic | | staff 2h | Horn 4.6 | Willow Staff 10.1 | Cedar Staff 14.8 | Journeyman's **16.8** (16–17) | 234 | 306k |

- **Every path reaches each weapon tier at the same levels: about 4, 9 to 10, 14, and 16 to 17 for
  the top.** At canon's prices the third tier came at 13 and the top at 15 to 16; the armour bought
  between them now costs what it stands for, which puts each weapon after it about a level later.
  The top weapon is still always the last thing a kit needs.
- **Buying every tier on the way costs about three quarters of a level.** A player who saved
  everything would own a 225,000 to 252,000 kit at about level 15.4 to 15.9, and the Zweihander's at
  about 17.1. Selling the old weapon back for half doesn't make up the difference. A Mystic's
  one-handed path finishes first because it has no 54,100 tier, so it saves without meaning to.
- **The Zweihander is the only long goal.** It costs 244,000 against 136,000 for every other top
  weapon, and it is the one path where saving pays off.
- **A Mystic's armour costs a fifth more than a Fighter's,** 108,711 against 88,567, because a robe
  stands for more of its part than light armour does (rules §7) and so counts for more.
- **A two-handed path's early shield costs it about a third of a level** on the way to its first
  two-hander: the Willow Staff comes at 10.1 rather than 9.8 to 9.9, and the shield is sold back for
  half once the two-hander is bought.
- **From level 16 to 18, the shop has nothing left but potions.** Adena keeps coming at 50,000 to
  90,000 a level, and a player reaches 20 holding 222,000 to 362,000 (290,000 to 430,000 at canon's
  prices). Gludio's D-grade gear will be
  bought with that, so price it against these figures, or give the village something to spend it on
  sooner.

### Time to level 20

Minutes of play to level 20 at the defaults, resting and fighting: before the fight had distance
(`30e1576`), once it had (`58c1d4c`), with the first skills where Lineage II taught them and
20-minute auras cast in the fight (`b47cf90`), with 2-minute auras raised before the pull
(`3a65708`), with every chest, legs and necklace priced as many of its slot as it stands for
(`6a43a98`), with Armor or Robe Mastery for each path (`613b52f`), and now, with Weapon Mastery and
Anti Magic for every set and every line past level 1 at Lineage II's prices (`87027a5` and Robe
Mastery's after it, and the Mystic's Weapon Mastery multiplying before it adds), the steps in one
column, then with the bench playing as a player would, with every shield costing 8 Evasion
and catching as aCis's do, and now with casts and reuses keeping what is left of a round and the
Dark Mystic's casts in a player's order (the only set that moved).
Each step is compared run for run (`bench/compare.exs`).

| Set | Path | Before distance | With distance | 20-minute auras | 2-minute auras | Pieces priced | Armor, Robe Mastery | Masteries | Bench plays meta | Shields cost Evasion | Now |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Human Fighter | sword 1h / 2h / dagger | 198 / 195 / 198 | 207 / 203 / 207 | 207 / 203 / 207 | 207 / 203 / 207 | 216 / 216 / 213 | 211 / 208 / 210 | 189 / 186 / 189 | 186 / 181 / 186 | 190 / 183 / 186 | 190 / 183 / 186 |
| Human Fighter | bow | 228 | 208 | 208 | 208 | 216 | 214 | 203 | 196 | 196 | 196 |
| Human Mystic | staff 1h / 2h | 207 / 215 | 191 / 191 | 191 / 192 | 191 / 192 | 195 / 198 | 191 / 193 | **183 / 183** | 183 / 183 | **182 / 183** | 174 / 175 |
| Elven Fighter | bow | 233 | 216 | 216 | 225 | 232 | 228 | 211 | 211 | 211 | 211 |
| Elven Mystic | staff 1h / 2h | 220 / 223 | 204 / 205 | 204 / 205 | 204 / 205 | 210 / 212 | 208 / 208 | 195 / 193 | 195 / 194 | 194 / 194 | **172 / 169** |
| Dark Fighter | dagger | 241 | 230 | 228 | 239 | 246 | 239 | 220 | 223 | 223 | 224 |
| Dark Mystic | staff 1h / 2h | 321 / 324 | 338 / 338 | 265 / 266 | 276 / 276 | 281 / 287 | 277 / 282 | 240 / 238 | 240 / 239 | 240 / 239 | 235 / 233 |
| Orc Fighter | fists / sword 1h / 2h | 264 / 280 / 262 | 271 / 286 / 269 | 268 / 281 / 266 | 268 / 281 / 266 | 282 / 291 / 281 | 278 / 286 / 277 | 247 / 253 / 246 | 245 / 252 / 246 | 245 / 255 / 247 | 245 / 255 / 247 |
| Orc Mystic | staff 1h / 2h | 312 / 312 | 309 / 309 | 280 / 286 | 291 / 298 | 289 / 294 | 277 / 280 | **274 / 273** | 274 / 274 | **273 / 274** | **272 / 273** |

- **The Dark Mystic casts as a player would and is 0.3% to 1.5% faster, drinking 5% to 12% fewer
  potions.** Three changes, each measured alone against the one before it:
  - Of two spells as strong, the cheaper goes first. From level 14 Wind Strike 3 and Vampiric
    Touch 1 are both power 21, and Vampiric Touch had opened every fight, its mend all overheal on
    a character still whole, for 28 MP where Wind Strike costs 15. This alone made the set 2.0% to
    2.3% faster.
  - Wind Shackle is laid on a monster with no spells once it has run in. It had been cast only while
    the spells rested, which from 14 they never did, so it was never cast at full MP; now a quarter
    to half of the fights have it. Time moves 0.0% to 0.7%, potions fall up to 9%, and resting at
    half the set dies in 4 runs of 600 rather than 11.
  - Curse: Poison ticks every second for 10 seconds and can take the last HP, and opens the fight on
    a monster that is not aggressive. With Lineage II's 3 seconds for 30 a poison dealt 28 to 53 HP
    a cast in fights of 8 to 23 seconds; now 80 to 146, about a Wind Strike's, and it is cast in
    every fight rather than at most one. Time moves 0.0% to 1.8% and potions fall 4% to 8%.

  The spread from the fastest set to the slowest is unchanged at every setting. Without a shield
  the Dark Mystic dies more to the Balor Orc Archer at 8, a passive bow whose first shots land
  while the poison is cast, but that build is off-meta: it dies more and is no faster.
- **A spell whose cast ends on a monster already felled strikes nothing,** where it once struck the
  body for nothing and rolled its magic critical. Only the Orc Mystic's burn fells a monster while a
  cast is under way, so only its runs move, re-seated by that one roll: 0.3% at most, its deaths on
  the meta paths not at all, and the spread from the fastest set to the slowest from 103.4 to 103.6
  minutes resting to full. Every other set's reading is identical.
- **Casts and reuses keeping what is left of a round make the Elven Mystic 11% to 16% faster, the
  Human Mystic 4% to 7%, and nothing else more than 2%.** A reuse used to wait for the round after
  it ran out, so each set's spells came round at the next whole round: Wind Strike, resting 5.2
  seconds for the Elf, 6.0 for the Human and 6.3 for the Dark Elf, came back after 6.7 for all
  three, and the Elf's Casting Spd. bought nothing. Now each comes back on time, and a set gains as
  much as its reuses sat below a round's end: the Elven Mystic's fights drop from 8.2 to 6.7 rounds
  and the Human Mystic's from 7.6 to 6.8, which saves rest as well (5 to 8 minutes for the Elf). The
  Dark Mystic gains 1%, its reuses already close to a round's end; the Orc Mystic nothing, its Chill
  Flame still burning when its reuse runs out; and the Fighters nothing, their blows already
  carrying their fraction and a weapon skill seldom used twice in a fight. The Elven Mystic two-hander is
  now the fastest set and past the bar's 15% resting below half (16.1% to 16.3%), which the game
  takes (`docs/direction.md`): the spread from the fastest set to the slowest widens from 92 to 103
  minutes resting to full, from 103 to 115 resting at half, and from 102 to 110 at 30%, and is
  unchanged carrying potions (117 to 116).
- **Every shield costing 8 Evasion and catching as aCis's do slows the one-handed sword Fighters
  by 1% to 2%, and the rest not at all.** A monster's blow lands up to 16 points more often (rules
  §13), and a shield gives back some of it, three times as often against an arrow or a critical and
  with five blows in a hundred caught perfectly: the Human Fighter is 2.1% slower and the Orc
  Fighter 1.1%, the two-handers, whose shield goes with the Broadsword, 0.4% to 1.0%. A Mystic,
  struck 96% to 98% of the time already, is up to 0.5% faster for the perfect catches, and the
  dagger and bow paths carry no shield. The spread from the fastest set to the slowest narrows from
  92.6 to 91.8 minutes. With 8 Evasion and the old catch (one in twenty perfect, no more against
  arrows or criticals) the Human Fighter was 3.5% slower and the spread widened to 94.6.
- **The bench playing as a player would makes the Human Fighter 1.3% to 3.5% faster,** since it
  buys only its own weapon's line and so reaches each tier's lines sooner; the bow most, whose Power
  Shot 4 no longer waits behind two other lines. The Orc Fighter moves under 1%, and the Dark
  Fighter, its dagger without a shield, is 1.5% slower. Nothing else moves past 0.6%.
- **The masteries and the canon prices make every set 1% to 16% faster** than Armor or Robe
  Mastery alone. Weapon Mastery does it: Anti Magic, measured alone, moved no set by more than 3%
  (the Elven Fighter, slower, for its SP). A Fighter's fight ends sooner, so it saves fighting (6 to
  14 minutes) and more rest (5 to 21), since each fight costs less HP; the melee Fighters gain 10%
  to 12%, the archers 5% to 7% (Power Shot's power matters more to them than P. Atk. does). The Dark
  Mystic gains most, 13.3% and 15.7% with the two-hander, past the bar's 15%, which the game takes:
  Wind Strike and Vampiric Touch grow with M. Atk. and its time was rest. The Orc Mystic gains least,
  1% to 3%, since Chill Flame burns for a fixed amount, so it is the slowest set by more: the spread
  from the fastest set to the slowest narrows from 95 to 91 minutes resting to full, and widens
  from 106 to 118 carrying potions. The hunts to 20 are the same, since a kill pays the same EXP:
  the time saved is all in the fights and the rest after them.
- **A Mystic's Weapon Mastery multiplies before it adds,** as Lineage II's server sorts it, where it
  once added first because its data lists the adds first: 0.3 M. Atk. and 0.7 P. Atk. less at level 7.
  No Mystic moved more than 0.5% at any setting; with a two-hander the Dark Mystic died once fewer
  resting below half and below 30%, and the Orc Mystic once fewer below 30%.
- **Armor or Robe Mastery for each path made every set 1% to 3% faster,** and the Orc Mystic 4% to 5%, which
  gives back about half of what pricing each piece cost; the spread from the fastest set to the
  slowest narrows from 100 to 95 minutes. A mastery adds only to defence, so it shortens no fight
  (fighting time moves by a minute at most): it saves rest, 3 to 7 minutes a path, since each fight
  costs less HP. The Orc Mystic saves most, 11 to 13 minutes.
- **Pricing each piece as it counts costs 2% to 6%,** and the Orc Mystic gains 1%. Income is
  unchanged, so the armour that now costs what it stands for is worn later, and every weapon bought
  after it too: the whole kit a level later, about 16 to 18 rather than 15 to 17. The two-handed
  Fighters pay most (6%), since their weapon was already the dearest. The Orc Mystic loses nothing:
  its spells hit from afar, so its armour mattered least. No set dies more resting to full, and the
  spread from the fastest set to the slowest narrows from 107 to 100 minutes.

- **Auras hold 2 minutes and are raised before the pull** (rules §19, §20), where they held 20 and
  were cast in the fight. The four sets with one, the Elven and Dark Fighters and the Dark and Orc
  Mystics, take 3% to 5% longer at every setting: every 2 minutes the aura's 5 to 10 MP is MP not
  spent on Mortal Blow or a spell, so a fight lasts half a round longer, and its cast is waited out
  before the pull. No set dies more. The spread from the fastest set to the slowest widens from 95
  to 107 minutes, since the Orc Mystic is both slowest and an aura's, the one part of the bar this
  fails.

- **A spell or a bow pulls from afar**, so the Human and Elven Mystics and the two archers reach 20
  sooner than before the fight had distance: their first spell or shot is free, and a melee monster
  spends rounds running in. **A melee Fighter pays 2% to 5%**, waiting while an aggressive monster
  runs at it and taking its first blow.
- **The Dark Mystic opens with Wind Strike** and learns Vampiric Touch at 14, as in Lineage II, and
  reaches 20 22% sooner. Its time was resting, not fighting (207 minutes of 338): Vampiric Touch
  cost 25 MP a cast where Wind Strike costs 9. The Elven Mystic's Wind Strike at 1 makes it 1%
  faster, and a Fighter's first skill at 5 costs nothing measurable.
- **The Orc Mystic casts Life Drain as a heal,** only below 85% of its HP (rules §20), and reaches
  20 in 280 to 286 minutes rather than 308 (291 to 298 since auras hold 2 minutes): Life Drain
  returns 80% of what it deals for 27 MP, and cast whenever it was ready it spent more MP than any
  spell in the game while the Orc Mystic was whole. Below 70% it would be 13% to 15% faster, but its
  deaths without potions doubled; below 85% they move within the dice's noise. It is still the
  slowest set, by 107 minutes to the Human Mystic (95 before auras held 2 minutes) where the gap
  was 147: its WIT gives the slowest Casting Spd., and Chill Flame burns three rounds after it is
  begun. Soul Cry left unused by the battle orders saves about 9% more.
- **The Orc Mystic has no Venom.** It was never cast: a poison comes only while the spells rest, and
  Chill Flame or Life Drain is always ready. Without it the set was 0.4% faster for its SP, then
  finishing its list at level 14 for 7,840 SP, and its level 7 lines are back at Lineage II's 520.
- **With potions and resting below half**, the Mystics took 11% to 13% longer once the fight had
  distance, since a fight lasts longer once a spell lands late, and buy far fewer potions.

### Survival

The bench at its defaults rests to full before every hunt, so survival is read with no potions and
resting only once a bar falls below a share, `harsh` and `harsher` in a `--final` matrix. Deaths of
200 runs a path with Weapon Mastery and Anti Magic and the late lines at Lineage II's prices, then
with the bench playing as a player would and every shield costing 8 Evasion, then now, with casts
and reuses keeping what is left of a round and the Dark Mystic's casts in a player's order:

| Set | Path | Rest below 50% | Rest below 30% | Most often killed by now |
|---|---|---|---|---|
| Human Mystic | staff 1h / 2h | 0 / 0, 0 / 0, 0 / 0 | 0 / 0, 0 / 0, 0 / 0 | |
| Elven Mystic | staff 1h / 2h | 3 / 4, 2 / 1, **0** / **0** | 1 / 4, 1 / 1, **0** / **0** | |
| Dark Mystic | staff 1h / 2h | 2 / 7, 0 / 5, 1 / 4 | 4 / 11, 0 / 9, 2 / 6 | Balor Orc Fighter at 10, Doom Soldier at 14 |
| Orc Mystic | staff 1h / 2h | 0 / 0, 0 / 1, 0 / 0 | 1 / 5, 0 / 5, 0 / 7 | Skeleton Longbowman, at 19 |
| Human Fighter | bow | 59, 8, 8 | 194, 81, 81 | Blade Spider, Talon Spider, at 16 to 18 |
| Elven Fighter | bow | 34, 34, 34 | 183, 183, 183 | Dread Soldier, Dungeon Skeleton Archer, at 13 and 14 |
| Dark Fighter | dagger | 14, 32, **20** | 125, 166, **148** | Doom Soldier, Balor Orc Fighter Leader, at 11 to 15 |
| Human Fighter | sword 1h / 2h / dagger | 0 / 11 / 23, 1 / 4 / 28, 0 / 6 / **18** | 65 / 156 / 173, 77 / 130 / 172, 72 / 136 / 177 | Blade Spider, Talon Spider, at 16 and 17 |
| Orc Fighter | fists | 10, 16, 16 | 189, 180, 180 | Skeleton Longbowman, at 19 |
| Orc Fighter | sword 1h / 2h | 40 / 10, 18 / 25, 14 / 18 | 198 / 199, 178 / 196, 174 / 197 | the Evil Eyes at 10, Skeleton Longbowman at 19 |

- **Casts and reuses keeping what is left of a round kill fewer dagger Fighters resting at half,**
  the Dark Fighter 32 to 20 and the Human Fighter 28 to 18, most likely for Mortal Blow, whose 7.4
  to 8.8 second reuse waited out a whole round more; at 30% the Dark Fighter dies in 148 rather than
  166, and the Human Fighter's dagger moves within the dice's noise (172 to 177). The Elven Mystic,
  its fights shorter, no longer dies at all, where it lost 1 to 2 runs of 200. Nothing else moves
  past the dice's noise.
- **The bench playing as a player would and every shield costing 8 Evasion move the risk-takers'
  deaths both ways.** The Human archer dies far less (59 to 8 resting at half, 194 to 81 at 30%),
  its Power Shot 4 no longer bought behind two other lines, and the Human two-hander less too. The
  Dark Fighter dies more, 14 to 32 and 125 to 166, from going without a shield, which under the old
  rule cut its deaths by half: the bench now flags that build when the rule lets it win, and under
  canon it does not (see the last section). A shield now costs 8 Evasion and catches as aCis's
  does, and that keeps those who carry one about as alive as the old free shield did: the Orc
  Fighter with a one-handed sword dies in 18 runs of 200 resting at half (40 before, 28 on the meta
  bench), its arrows from the Skeleton Longbowman now caught three times as often, and every Mystic
  with a shield as often or less. Only the Human Fighter with a one-handed sword resting at 30% dies
  more, 30 to 77 on the meta bench, past the dice's noise, which the game takes as canon's.
- **Resting at half without potions, the masteries and the canon prices halve or better the
  deaths of every Fighter but the Human archer,** the Elven Fighter's (68 to 34) with the canon
  prices' help, and the Orc Fighter's most: it dies in 10 to 40 runs of 200 where it died in 91 to
  141. Resting at 30%, nearly every Fighter still dies. Weapon Mastery ends a fight sooner, so less HP is lost to
  it. Anti Magic is the Orc Fighter's: its level 10 deaths are to the Evil Eyes' spells, which only
  M. Def. turns aside, and at 400 runs Weapon Mastery alone left 35 / 90 / 57 deaths, both 21 / 74 /
  20. What still kills it is the Skeleton Longbowman's arrows at 19. Elsewhere Anti Magic only costs
  SP, since no other village ground casts much: alone it killed more of the other Fighters (the
  Human archer 102 to 146 of 400), and together with Weapon Mastery the Human archer dies in 59 of
  200 where it died in 47, within the dice's noise, nearly all at 16 and 17, its Power Shot 4 bought
  later behind dearer lists. Gludio's and Dion's grounds, whose monsters cast, are where it will
  matter, and whether to learn it is the player's call. The Mystics barely move, as little reaches
  them.

- **Armor or Robe Mastery for each path gave back what pricing each piece took from those who take
  risks,** and more (deaths of 400). Resting at half without potions, every Fighter died less than
  at canon's prices, and the Orc Mystic almost never. The Dark Mystic, whom the prices hurt most, falls from 30 / 81 to 5 / 23, not
  back to 3 / 7: what is left is the Balor Orc Fighter at level 10, before Robe Mastery 1 has much to
  add to, and that ground's melee monsters at 10 to 13 remain the lever. The Orc Fighter's deaths at
  10 are to the Evil Eyes' spells, which P. Def. does not turn aside. Robe Mastery gives every Mystic
  twice what Lineage II's Armor Mastery gave the Human, Elven and Dark Mystics: with Armor Mastery
  instead the Dark Mystic died in 9 / 38 runs of 400, and the others as with Robe Mastery.

- **Pricing each piece as it counts kills more of those who take risks,** and fails the bar here,
  accepted as the price of pricing every piece by one rule. A Fighter resting at half dies in 21 to
  102 more runs of 400, between levels 10 and 19, where its armour and its third and fourth weapons
  now come about a level later. The Dark Mystic dies most for it, at levels 10 to 13 to the Skeleton
  Hunters and Balor Orc Fighters, who reach it in melee: its robes cost the most of any armour, and
  the two-hander, saving for its Cedar Staff too, wears them latest. The other Mystics, whom little
  reaches, barely move.

- **Fighting from afar keeps a Mystic alive**, and an archer too. A heal before the pull (rules §20)
  starts each fight topped up, and the opening spell lands before the monster has come.
- **An aura raised before the pull saves the round its cast took in the fight.** Against 20-minute
  auras it kills fewer, not more: resting at half without potions, the Elven Fighter dies in 184 runs
  rather than 216 and the Dark Mystic with a two-hander in 7 rather than 25.
- **A heal before the pull is set below 70% to begin with.** Measured at each share the orders
  offer, resting at half or less without potions: below 50% the Dark Mystic died in 213 to 329 runs
  of 400 at levels 10 to 13, since Wind Strike, unlike the Vampiric Touch it opened with before,
  heals nothing, and the Skeleton Hunters and Balor Orc Fighters on its ground come before Vampiric
  Touch at 14; below 70% it dies in 3 to 26, the Elven Mystic in none and the Elven Fighter in 225
  rather than 296, for 2% to 9% more time. Below 30% killed far more of every healer. Resting to
  full, the share changes nothing.
- **A heal cast in the fight costs more than it mends**, now that it takes effect as its cast ends:
  the Dark Mystic's Self Heal, 5 seconds of being struck for 45 HP, lost 73 runs of 400 where never
  healing in the fight lost 13, and healing below 30% came too late to save more. So the fight's heal
  order starts at never, and the Elven Fighter, whose Elemental Heal no longer fires mid-fight,
  survives a quarter of its runs.
- **One heal a set.** The Elven Mystic once knew Self Heal and Heal, each on a reuse of its own,
  so it cast one while the other rested. Learning Heal from level 1 instead, and never Self Heal,
  moved its road to 20 by 0.1% at most in every setting, and no deaths. Topping up from 30% to 70%
  before a pull takes it 14.3 seconds rather than 9.3, a few times a ladder, so the second heal
  was clutter that cost nothing to lose.
- **The Skeleton Longbowman**, an aggressive archer at level 19 on the Orc Village's ground, shoots a
  melee character for the 460 it must run, and kills the Orc Fighter with fists twice as often.
- **Measured and dropped:** a heal before the spells in the fight, alone or taking turns, which
  killed every Human and Elven Mystic run; heals to full before the pull and after the kill, which
  slowed the Mystics 16% to 70%; Soul Cry lit at the pull by a Mystic, which drained its MP for the
  whole fight from afar and cost the Orc Mystic 20% (it now lights once its blows reach); a
  2-minute aura still cast in the fight, which cost as much time as raising it before the pull and a
  round of being struck besides, so resting at half without potions the Dark Mystic died in 42 to 57
  runs of 400 and the Elven Fighter in 258; curses only
  while the monster is still running in, 2% to 3% faster for the Dark Mystic but its Wind Shackle
  was what held a monster off it in melee, so its deaths more than doubled; Ice Bolt slowing the
  run alone, as in Lineage II, which let the Sukar Wererat Leader kill the Elven Mystic at level
  19 in 256 to 360 runs of 400 without potions; the Orc Mystic with Soul Cry alone until Chill Flame at 7, as in
  Lineage II, which died at levels 2 to 7 even resting to full (59 runs of 400) and took 20% longer;
  and Lineage II's poison, 3 seconds a tick for 30, cast before the spells, while the monster is
  above half or only while it runs in, which slowed the Orc Mystic 21% and the Dark Mystic 6% to
  13%, since it was slow damage that could not take the last HP, bought with a 4-second cast; every drain cast only below a share of HP,
  which slowed the Dark Mystic and killed more Dark Fighters, where Life Drain alone pays; the
  six slow casters (the golems, the zombies and the Undead Slave) casting their power-5 poke with
  Lineage II's odds, mostly at a character that is not hitting them, rather than whenever it is
  ready, which moved no set by more than 1%; Wind Shackle cast at the pull, 5% to 7% slower for the
  Dark Mystic, the pull no longer a free Wind Strike and a slowed swing worth less than that; and
  the faster Curse: Poison laid first on every monster, an aggressive one too, 4% to 7% slower,
  and resting at half without potions the Dark Mystic died in 99 runs of 600 rather than 4, most
  to the Cave Fang Spider at 16, whose blows a poison's slow damage did not outrun. Laid only once
  the fight was under way it was 1% to 3% slower and died as often.
- **The Skeleton Longbowman is the Orc Village ground's hard top rung,** as the Sukar Wererat Leader
  is the Elven ground's: against a full kit at 19 it costs an Orc Fighter 45% to 52% of its HP a
  fight (about 60 of them while the Fighter runs 460 in under its arrows), where the Leader costs
  the Elven Fighter 66% and the rest of either ground 18% to 34%. Its numbers are canon. Neither
  kills a Fighter resting to full or carrying potions; from half HP, the Longbowman wins 29% to 66%
  of fights.
- **An Evil Eye beside a character burns it, and drains or strikes it only from afar,** as Lineage
  II's casters choose their spell by distance. It casts back to back, as theirs did, and never
  swings while its MP lasts. When it cast its strongest spell at any distance, the Evil Eye Watcher's
  HP Drain killed a level 10 Orc Fighter in its gear from full HP in 47% to 100% of fights without
  potions, and resting at half killed 157 to 296 runs of 400 at level 10. Burning with Aura Burn
  beside it, it takes 54% to 56% of that Fighter's HP and kills none from full; deaths at 10 fall to
  25 to 73, the Orc Fighter is 1% faster, and the Orc Mystic, which it meets from afar, is unmoved.
- **Every fighter starts with a Squire's weapon for each of its paths** (rules §23), none of which a
  shop buys back, where the Elven Fighter started with a Short Bow it could sell for 384. Both bow
  paths buy a Short Bow at level 4, so time to level 20 moves 0.4% at most. Resting at half, the
  Human and Elven Fighters' bow deaths went from 106 and 184 to 121 and 189, nearly all at level 16
  and above: the weaker bow changes only the first fights, which re-seats every roll after them, and
  `compare.exs` reads it as the dice's noise.
- **The bench once killed the Orc Fighter with a sword** at levels 3 to 5, 38 runs of 400 with
  potions: its paths counted only the village's stock as their weapons, so the sword path never
  wielded the Squire's Sword it starts with, and a Leather Shield bought early took off its
  two-handed Squire's Gloves. A path now counts its set's starting weapons, and that set dies none.

### Off-meta builds

The bench runs each one-handed path again with the other shield choice, on the same dice, and flags
the build when it dies less than the path past the dice's noise, or is more than 2% faster without
dying more. The lines are at the end of each setting's report (`Off-meta …`).

| Off-meta build | Old rule, resting at half / 30% | Canon now, resting at half / 30% | Time to 20, canon now |
|---|---|---|---|
| Human Fighter, dagger with a shield | **flagged**: 28 to 12, 172 to 128 deaths | 18 to 19, 177 to 186 | 1.3% to 4.9% slower |
| Dark Fighter, dagger with a shield | **flagged**: 32 to 14, 166 to 125 | 20 to 24, 148 to 170 | 0.4% to 2.8% slower |
| Human Fighter, one-handed sword without one | 0 to 1, 30 to 83 | 0 to 0, 72 to 70 | 1.0% to 1.8% faster |
| Orc Fighter, one-handed sword without one | 28 to 40, 192 to 194 | 14 to 35, 174 to 194 | 0.6% to 0.8% faster |
| Any Mystic, one-handed staff without one | the same or more | the same or more (Dark Mystic 1 to 11 at half, 2 to 16 at 30%, to the Balor Orc Archer at 8) | up to 1.7% slower, the Dark Mystic within 0.3% |

- **A dagger with a shield was the strongest build under the old rule,** a shield's block for
  nothing: it halved the dagger Fighters' deaths. With every shield costing 8 Evasion, as in Lineage
  II, a dagger does better without one, which is the meta the bench plays.
- **A one-handed sword keeps its shield as a choice between speed and safety:** without one it is
  up to 2% faster, and the Orc Fighter dies more than twice as often resting at half; the Human
  Fighter, which a shield barely keeps alive, dies about as often. Measured with the
  old catch, before arrows and criticals were caught three times as often, it was flagged for the
  Human Fighter, 2.3% to 3.3% faster and dying less.
- **A Mystic keeps its shield:** a monster already strikes it 96% to 98% of the time, so the
  Evasion costs it almost nothing and the block is worth having.
- **No build is flagged under canon.** A mastery that raises the block rate (Lineage II's Shield
  Mastery, a Knight's from level 20) would come with the class change.

### Both together

The shop runs out at about hunt 200 to 280 and level 16 to 18, and the trainer at hunt 190 to 290
and level 16 to 17, now that it teaches three masteries a set. From there to level 20, a run has nothing to buy and
only the level to climb. That stretch is where the class change, the Temple's buffs, and Gludio's first ground and
shops will matter most.
