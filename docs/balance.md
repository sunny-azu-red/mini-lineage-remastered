# Mini-Lineage: balance, measured

What the village ladder costs and pays, read off `bench/ladder.exs`. The rules (`docs/rules.md`) say
what things cost; this says when a player can afford them. Every figure here was measured, never
worked out by hand, and holds only for the rules it was measured against.

**Measured** on rules §1 to §26 as they now stand: the fight of §20 on a line between the two,
spells that take effect as their cast ends, the battle orders, and the first skills where Lineage II
taught them (a Fighter's at level 5, Wind Strike for every Mystic but the Orc), Life Drain cast as
a heal, the Evil Eyes choosing their spell by distance, and auras that hold 2 minutes, raised before
the pull, each fighter's kit a Squire's weapon for every path its skills take, the Orc Mystic's an
Apprentice's Wand, each path shown only its own goods, one of each kind per price, every chest,
legs and necklace priced as many of its slot as it stands for, and three masteries on every path,
Armor Mastery for a Fighter and Robe Mastery for every Mystic, and Weapon Mastery and Anti Magic for
both, each multiplying before it adds as Lineage II does, and every line at Lineage II's price but
level 1's. One `--final` reading of that
build, 200 seeded runs of every set up its village's ladder to
level 20, once per weapon path its skills can use, each run seeded on its own; at the defaults none
of them died. The bench learns every line, the masteries included, which a player need not.

**Rerun it** after anything that moves a fight's numbers, a price, a monster's SP or Adena, or the
trainer's list, and rewrite these tables from what it prints (seconds, its runs in parallel):

    MIX_ENV=test mix run --no-start bench/ladder.exs [runs] [top level] [rest below %] [potions kept]
      [--json path] [--only "Set name,Set name"] [--orders <pull share>,<fight share>]
    MIX_ENV=test mix run --no-start bench/ladder.exs --matrix <path prefix> [--final] [runs]
      [--only "Set name,Set name"]

`--matrix` takes the study's readings in one go, 200 runs a path unless told otherwise, each into
`<prefix>_<setting>.txt` and `.json`: `defaults` (resting to full, 20 potions), `harsh` (resting
below half, none) and `potions` (below half, 20), and with `--final` `harsher` (below 30%, none) as
well, which most Fighters do not survive and so is kept for the reading these tables come from. The
whole `--final` matrix takes about 2 minutes on 8 cores, a routine one about a minute and a half,
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

**How the bench plays**, at its defaults: it rests to full before every hunt and keeps 20 Lesser
Healing Potions. It learns every line the trainer offers as soon as it can pay for it. At the shop it
buys the best upgrade it can afford in each slot, weapon first, and sells back the piece it replaced.
A path is a weapon type and the hands it is held in. A one-handed path adds a shield. A two-handed
path holds one-handers only until its first two-hander is affordable, then skips straight to the
two-handers (the Zweihander path never buys a Long Sword).

## The trainer: SP

Every set earns about **32,500 SP** from level 1 to 20, and three quarters of it comes after level 15.
SP doesn't depend on the weapon path, so there is one row per set.

| Set | Skills (lines) | Whole list | Of it, Weapon Mastery and Anti Magic | Learned at level | …at hunt | SP saved at 20 |
|---|---|---|---|---|---|---|
| Human Fighter | 6 (20) | 28,630 | 7,940 | 19 | 316 of 347 | 3,900 |
| Elven Fighter | 6 (14) | 19,360 | 7,090 | 17 | 290 of 414 | 13,600 |
| Dark Fighter | 6 (14) | 18,120 | 6,650 | 17 | 273 of 395 | 14,800 |
| Orc Fighter | 6 (17) | 24,390 | 7,770 | 18 | 316 of 385 | 8,500 |
| Human Mystic | 6 (12) | 12,940 | 5,250 | 16 | 190 of 347 | 19,600 |
| Elven Mystic | 7 (14) | 15,720 | 5,340 | 17 | 253 of 414 | 17,200 |
| Dark Mystic | 9 (14) | 15,500 | 5,250 | 16 | 245 of 395 | 17,400 |
| Orc Mystic | 7 (13) | 13,370 | 4,600 | 16 | 205 of 385 | 19,500 |

A tier's lines are taught at one character level (1, 5, 10 and 15 for a Fighter; 1, 7 and 14 for a
Mystic), and no two lines of one skill share one. The wait is how many hunts pass between reaching
that level and buying a line taught there, shown as average / worst:

| Set | Level 1 | First tier | Second | Third |
|---|---|---|---|---|
| Human Fighter | 7 / 10 | L5: 17 / 40 | L10: 57 / 106 | L15: 97 / 166 |
| Elven Fighter | | L5: 16 / 39 | L10: 40 / 84 | L15: 63 / 120 |
| Dark Fighter | | L5: 13 / 34 | L10: 41 / 89 | L15: 58 / 110 |
| Orc Fighter | 6 / 6 | L5: 21 / 48 | L10: 63 / 106 | L15: 96 / 161 |
| Human Mystic | 5 / 5 | L7: 29 / 54 | L14: 24 / 65 | |
| Elven Mystic | 5 / 5 | L7: 37 / 66 | L14: 52 / 117 | |
| Dark Mystic | 5 / 5 | L7: 34 / 63 | L14: 49 / 113 | |
| Orc Mystic | 5 / 5 | L7: 33 / 59 | L14: 30 / 77 | |

- **Every set starts knowing its first skill,** a Fighter the one its starting weapon uses, and all
  but the Elven and Dark Fighters find something at the trainer at level 1, bought after 5 to 7
  hunts: a Mystic's Self Heal or Soul Cry, the Human Fighter's Mortal Blow and Power Shot, the Orc
  Fighter's Power Strike. Moving a Fighter's first skill from 5 to 1 changed no set by more than
  1.4%; a Mystic made to buy its first spell instead died at levels 1 to 3 in nine runs of ten.
- **No tier is empty, and every set can afford its whole list.** Each tier's first line can be bought
  on arrival, and every tier past level 1 offers four to six lines, two or three of them masteries,
  so the player chooses the order.
- **The masteries are bought after the skills they fight with,** from what is left: the bench buys
  a tier's lines in the trainer's order, the masteries last (Armor or Robe Mastery, then Weapon
  Mastery, then Anti Magic), so they stretch the list rather than delay a skill. Weapon Mastery and
  Anti Magic cost 4,600 to 7,940 SP a set, and every tier waits longer: at the last tier 24 to 97
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
- **Every list is learned at 16 to 19,** a Mystic's at 16 to 17 and a Fighter's at 17 to 19: a
  Mystic's masteries hold two lines to a Fighter's three, and its fights spend MP rather than SP.
- **The Human Fighter pays the most and finishes last,** its 28,630 learned at level 19 with 3,900
  SP to spare. Half of it buys Mortal Blow and Power Shot, which only work with a dagger or a bow, and
  the bench buys every line; a player who stays with one weapon finishes sooner and saves more.
- **From the end of the list to level 20, the trainer has nothing left to sell.** That is 31 to 180
  hunts while SP builds up for the class change: 17,200 to 19,600 for a Mystic and 3,900 to 14,800
  for a Fighter (11,900 to 17,700 for every set before Weapon Mastery and Anti Magic). A first tier
  of class-change skills is best priced per class against these, what a set that learned everything
  can afford on reaching 20; one that skipped a mastery has more.

## The shop: Adena

Gross Adena earned from monsters, by the level reached. Each figure is the range across sets.
Talking Island sits at the low end from level 16, because its ground tops out at level 17.

| Level | 5 | 10 | 12 | 14 | 15 | 16 | 17 | 18 | 20 |
|---|---|---|---|---|---|---|---|---|---|
| Earned | 2k | 32–33k | 77–79k | 153–159k | 201–214k | 258–279k | 321–351k | 400–437k | 615–647k |

The best kit each path can buy in its village, priced in rules §24. Armour is the best chest and legs
plus the Necklace of Wisdom, each priced as many of its slot as it stands for: 88,567 in light armour
(Bone Breastplate 33,397, Bone Gaiters 17,639, the necklace 37,531) and 108,711 in robes (Tunic of
Devotion 47,367, Stockings of Devotion 23,813), where both were 44,900 at canon's prices.

| Path | Weapon | Shield | Whole kit |
|---|---|---|---|
| Sword 1h | Long Sword 136,000 | Round Shield 7,110 | 231,677 |
| Sword 2h | Zweihander 244,000 | | 332,567 |
| Dagger | Throwing Knife 136,000 | Round Shield 7,110 | 231,677 |
| Bow | Forest Bow 136,000 | | 224,567 |
| Fists (Orc Village) | Cestus 136,000 | | 224,567 |
| Staff 1h | Relic of The Saints 136,000 | Round Shield 7,110 | 251,821 |
| Staff 2h | Journeyman's Staff 136,000 | | 244,711 |

The level each of a path's weapons is first held at, then the level and hunt the whole kit is worn
(the weapon is always the last piece bought), then the Adena still held at level 20:

| Set | Skill | Path | 768 | 12,500 | 54,100 | Top weapon, kit | Hunt | Held at 20 |
|---|---|---|---|---|---|---|---|---|
| Human Fighter | Power Strike | sword 1h | Short Sword 4.4 | Broadsword 10.0 | Gladius 14.2 | Long Sword **16.5** (16–17) | 211 | 325k |
| Human Fighter | Power Strike | sword 2h | Short Sword 4.0 | Broadsword 9.4 | Brandish 14.1 | Zweihander **17.8** (17–18) | 256 | 227k |
| Human Fighter | Mortal Blow | dagger | Bone Dagger 4.4 | Knife 10.0 | Dirk 14.2 | Throwing Knife **16.5** (16–17) | 211 | 325k |
| Human Fighter | Power Shot | bow | Short Bow 4.1 | Bow 9.4 | Hunting Bow 14.1 | Forest Bow **16.3** (16–17) | 207 | 334k |
| Elven Fighter | Power Shot | bow | Short Bow 4.2 | Bow 9.4 | Hunting Bow 14.0 | Forest Bow **16.0** (16–17) | 233 | 363k |
| Dark Fighter | Mortal Blow | dagger | Bone Dagger 4.5 | Knife 10.0 | Dirk 14.0 | Throwing Knife **16.0** (16–17) | 229 | 335k |
| Orc Fighter | Iron Punch | fists | Spiked Gloves 4.2 | Iron Gloves 9.4 | Fox Claw Gloves 14.0 | Cestus **16.1** (16–17) | 216 | 341k |
| Orc Fighter | Power Strike | sword 1h | Short Sword 4.5 | Broadsword 10.0 | Gladius 14.2 | Long Sword **16.3** (16–17) | 223 | 327k |
| Orc Fighter | Power Strike | sword 2h | Short Sword 4.2 | Broadsword 9.4 | Brandish 14.1 | Zweihander **17.5** (17–18) | 276 | 229k |
| Human Mystic | | staff 1h | Horn 4.4 | Scholar's Tome 10.1 | | Relic **16.1** (16–17) | 200 | 327k |
| Human Mystic | | staff 2h | Horn 4.2 | Willow Staff 9.8 | Cedar Staff 14.6 | Journeyman's **16.8** (16–17) | 218 | 309k |
| Elven Mystic | | staff 1h | Horn 4.5 | Scholar's Tome 10.1 | | Relic **16.0** (15–16) | 225 | 355k |
| Elven Mystic | | staff 2h | Horn 4.3 | Willow Staff 9.9 | Cedar Staff 14.4 | Journeyman's **16.3** (16–17) | 247 | 337k |
| Dark Mystic | | staff 1h | Horn 4.6 | Scholar's Tome 10.1 | | Relic **16.0** (15–16) | 216 | 338k |
| Dark Mystic | | staff 2h | Horn 4.3 | Willow Staff 9.9 | Cedar Staff 14.3 | Journeyman's **16.2** (16–17) | 238 | 320k |
| Orc Mystic | | staff 1h | Horn 4.6 | Scholar's Tome 10.1 | | Relic **16.0** (15–17) | 210 | 330k |
| Orc Mystic | | staff 2h | Horn 4.3 | Willow Staff 9.9 | Cedar Staff 14.7 | Journeyman's **16.6** (16–17) | 230 | 315k |

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
- **From level 16 to 18, the shop has nothing left but potions.** Adena keeps coming at 50,000 to
  90,000 a level, and a player reaches 20 holding 227,000 to 363,000 (290,000 to 430,000 at canon's
  prices). Gludio's D-grade gear will be
  bought with that, so price it against these figures, or give the village something to spend it on
  sooner.

## Time to level 20

Minutes of play to level 20 at the defaults, resting and fighting: before the fight had distance
(`30e1576`), once it had (`58c1d4c`), with the first skills where Lineage II taught them and
20-minute auras cast in the fight (`b47cf90`), with 2-minute auras raised before the pull
(`3a65708`), with every chest, legs and necklace priced as many of its slot as it stands for
(`6a43a98`), with Armor or Robe Mastery for each path (`613b52f`), and now, with Weapon Mastery and
Anti Magic for every set and every line past level 1 at Lineage II's prices (`87027a5` and Robe
Mastery's after it, and the Mystic's Weapon Mastery multiplying before it adds), the steps in one
column. Each step is compared run for run (`bench/compare.exs`).

| Set | Path | Before distance | With distance | 20-minute auras | 2-minute auras | Pieces priced | Armor, Robe Mastery | Now |
|---|---|---|---|---|---|---|---|---|
| Human Fighter | sword 1h / 2h / dagger | 198 / 195 / 198 | 207 / 203 / 207 | 207 / 203 / 207 | 207 / 203 / 207 | 216 / 216 / 213 | 211 / 208 / 210 | 189 / 186 / 189 |
| Human Fighter | bow | 228 | 208 | 208 | 208 | 216 | 214 | 203 |
| Human Mystic | staff 1h / 2h | 207 / 215 | 191 / 191 | 191 / 192 | 191 / 192 | 195 / 198 | 191 / 193 | **183 / 183** |
| Elven Fighter | bow | 233 | 216 | 216 | 225 | 232 | 228 | 211 |
| Elven Mystic | staff 1h / 2h | 220 / 223 | 204 / 205 | 204 / 205 | 204 / 205 | 210 / 212 | 208 / 208 | 195 / 193 |
| Dark Fighter | dagger | 241 | 230 | 228 | 239 | 246 | 239 | 220 |
| Dark Mystic | staff 1h / 2h | 321 / 324 | 338 / 338 | 265 / 266 | 276 / 276 | 281 / 287 | 277 / 282 | 240 / 238 |
| Orc Fighter | fists / sword 1h / 2h | 264 / 280 / 262 | 271 / 286 / 269 | 268 / 281 / 266 | 268 / 281 / 266 | 282 / 291 / 281 | 278 / 286 / 277 | 247 / 253 / 246 |
| Orc Mystic | staff 1h / 2h | 312 / 312 | 309 / 309 | 280 / 286 | 291 / 298 | 289 / 294 | 277 / 280 | **274 / 273** |

- **The masteries and the canon prices make every set 1% to 16% faster** than Armor or Robe
  Mastery alone. Weapon Mastery does it: Anti Magic, measured alone, moved no set by more than 3%
  (the Elven Fighter, slower, for its SP). A Fighter's fight ends sooner, so it saves fighting (6 to
  14 minutes) and more rest (5 to 21), since each fight costs less HP; the melee Fighters gain 10%
  to 12%, the archers 5% to 7% (Power Shot's power matters more to them than P.Atk does). The Dark
  Mystic gains most, 13.3% and 15.7% with the two-hander, past the bar's 15%, which the game takes:
  Wind Strike and Vampiric Touch grow with M.Atk and its time was rest. The Orc Mystic gains least,
  1% to 3%, since Chill Flame burns for a fixed amount, so it is the slowest set by more: the spread
  from the fastest set to the slowest narrows from 95 to 91 minutes resting to full, and widens
  from 106 to 118 carrying potions. The hunts to 20 are the same, since a kill pays the same EXP:
  the time saved is all in the fights and the rest after them.
- **A Mystic's Weapon Mastery multiplies before it adds,** as Lineage II's server sorts it, where it
  once added first because its data lists the adds first: 0.3 M.Atk and 0.7 P.Atk less at level 7.
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

## Survival

The bench at its defaults rests to full before every hunt, so survival is read with no potions and
resting only once a bar falls below a share, `harsh` and `harsher` in a `--final` matrix. Deaths of
200 runs a path with Armor or Robe Mastery alone (`613b52f`), then now, with Weapon Mastery and Anti
Magic as well and the late lines at Lineage II's prices:

| Set | Path | Rest below 50% | Rest below 30% | Most often killed by now |
|---|---|---|---|---|
| Human Mystic | staff 1h / 2h | 0 / 0, 0 / 0 | 0 / 0, 0 / 0 | |
| Elven Mystic | staff 1h / 2h | 3 / 4, 3 / 4 | 1 / 4, 1 / 4 | Spore Fungus, at 9 |
| Dark Mystic | staff 1h / 2h | 3 / 7, **2 / 7** | 5 / 12, 4 / 11 | Balor Orc Fighter, at 10 |
| Orc Mystic | staff 1h / 2h | 0 / 1, **0 / 0** | 5 / 10, **1 / 5** | Skeleton Longbowman, at 19 |
| Human Fighter | bow | 47, 59 | 191, 194 | Blade Spider, Talon Spider, at 16 and 17 |
| Elven Fighter | bow | 68, **34** | 197, 183 | Dark Terror, Dread Soldier |
| Dark Fighter | dagger | 60, **14** | 180, **125** | Balor Orc Archer, Cave Fang Spider |
| Human Fighter | sword 1h / 2h / dagger | 2 / 55 / 59, **0 / 11 / 23** | 161 / 199 / 196, **65 / 156 / 173** | Blade Spider, Talon Spider |
| Orc Fighter | fists | 118, **10** | 199, 189 | Skeleton Longbowman, at 19 |
| Orc Fighter | sword 1h / 2h | 141 / 91, **40 / 10** | 200 / 200, 198 / 199 | Evil Eye Watcher, Skeleton Longbowman |

- **Resting at half without potions, the masteries and the canon prices halve or better the
  deaths of every Fighter but the Human archer,** the Elven Fighter's (68 to 34) with the canon
  prices' help, and the Orc Fighter's most: it dies in 10 to 40 runs of 200 where it died in 91 to
  141. Resting at 30%, nearly every Fighter still dies. Weapon Mastery ends a fight sooner, so less HP is lost to
  it. Anti Magic is the Orc Fighter's: its level 10 deaths are to the Evil Eyes' spells, which only
  M.Def turns aside, and at 400 runs Weapon Mastery alone left 35 / 90 / 57 deaths, both 21 / 74 /
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
  10 are to the Evil Eyes' spells, which P.Def does not turn aside. Robe Mastery gives every Mystic
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
  and a poison cast before the spells, while the monster is above half or only while it runs in,
  which slowed the Orc Mystic 21% and the Dark Mystic 6% to 13%, since a poison is slow damage that
  cannot take the last HP, bought with a 4-second cast; every drain cast only below a share of HP,
  which slowed the Dark Mystic and killed more Dark Fighters, where Life Drain alone pays; and the
  six slow casters (the golems, the zombies and the Undead Slave) casting their power-5 poke with
  Lineage II's odds, mostly at a character that is not hitting them, rather than whenever it is
  ready, which moved no set by more than 1%.
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

## Both together

The shop runs out at about hunt 200 to 275 and level 16 to 18, and the trainer at hunt 190 to 316
and level 17 to 19, now that it teaches three masteries a set. From there to level 20, a run has nothing to buy and
only the level to climb. That stretch is where the class change, the Temple's buffs, and Gludio's first ground and
shops will matter most.
