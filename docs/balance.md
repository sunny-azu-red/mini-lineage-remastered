# Mini-Lineage: balance, measured

What the village ladder costs and pays, read off `bench/ladder.exs`. The rules (`docs/rules.md`) say
what things cost; this says when a player can afford them. Every figure here was measured, never
worked out by hand, and holds only for the rules it was measured against.

**Measured** on rules §1 to §26 as they now stand: the fight of §20 on a line between the two,
spells that take effect as their cast ends, the battle orders, and the first skills where Lineage II
taught them (a Fighter's at level 5, Wind Strike for every Mystic but the Orc). 400 seeded runs of
every set up its village's ladder to level 20, once per weapon path its skills can use, each run
seeded on its own; at the defaults none of them died.

**Rerun it** after anything that moves a fight's numbers, a price, a monster's SP or Adena, or the
trainer's list, and rewrite these tables from what it prints (seconds, its runs in parallel):

    MIX_ENV=test mix run --no-start bench/ladder.exs [runs] [top level] [rest below %] [potions kept]
      [--json path] [--only "Set name"] [--orders <pull share>,<fight share>]

Each run's dice are seeded from its set and number, so a change moves only the runs it touches. To
judge a change, take a `--json` reading on the build before it (a `git worktree`) and one after with
the same settings, and read them with `bench/compare.exs before.json after.json`, which holds them
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

| Set | Skills (lines) | Whole list | Learned at level | …at hunt | SP saved at 20 |
|---|---|---|---|---|---|
| Human Fighter | 3 (12) | 15,480 | 16 | 210 of 347 | 17,100 |
| Elven Fighter | 3 (7) | 11,840 | 15.3 (15–16) | 210 of 414 | 21,100 |
| Dark Fighter | 3 (7) | 11,890 | 16.0 (15–16) | 205 of 395 | 21,000 |
| Orc Fighter | 3 (9) | 11,110 | 15 | 182 of 385 | 21,800 |
| Human Mystic | 3 (7) | 9,010 | 14.7 (14–15) | 155 of 347 | 23,500 |
| Elven Mystic | 4 (10) | 8,100 | 14 | 162 of 414 | 24,900 |
| Dark Mystic | 6 (9) | 9,470 | 15 | 175 of 395 | 23,400 |
| Orc Mystic | 4 (7) | 7,840 | 14 | 146 of 385 | 25,000 |

A tier's lines are taught at one character level (5, 10 and 15 for a Fighter; 1, 7 and 14 for a
Mystic, whose level 1 is its first spell and one more). The wait is how many hunts pass between
reaching that level and buying a line taught there, shown as average / worst:

| Set | First tier | Second | Third |
|---|---|---|---|
| Human Fighter | L5: 6 / 19 | L10: 20 / 42 | L15: 26 / 58 |
| Elven Fighter | L5: 5 / 15 | L10: 0 / 0 | L15: 12 / 40 |
| Dark Fighter | L5: 1 / 6 | L10: 5 / 11 | L15: 15 / 40 |
| Orc Fighter | L5: 8 / 24 | L10: 21 / 37 | L15: 11 / 27 |
| Human Mystic | L7: 9 / 24 | L14: 12 / 28 | |
| Elven Mystic | L7: 14 / 37 | L14: 7 / 25 | |
| Dark Mystic | L7: 19 / 36 | L14: 10 / 42 | |
| Orc Mystic | L7: 16 / 26 | L14: 5 / 17 | |

- **No tier is empty, and every set can afford its whole list.** Each tier's first line can be bought
  on arrival. One tier holds a single line, the Elven Fighter's at 10 (Power Shot 3), bought at
  once. Every other tier offers two to five lines, so the player chooses the order.
- **A Fighter fights its first four levels with blows alone,** about 10 hunts, and buys its first
  skill and its second line on reaching 5. That costs it nothing measurable on the road to 20.
- **The Mystics finish about a level sooner** (14 to 15, against 15 to 16). Their skills have fewer
  steps, and their fights spend MP rather than SP.
- **The Human Fighter pays the most and finishes last.** About half its 15,480 buys Mortal Blow and
  Power Shot, which only work with a dagger or a bow. A player who stays with the sword finishes
  around 15 and saves more.
- **From the end of the list to level 20, the trainer has nothing left to sell.** That is 140 to 250
  hunts while 17,000 to 25,000 SP builds up for the class change. A first tier of class-change skills
  priced at about 15,000 to 20,000, affordable on reaching 20, would turn that pile into an immediate
  jump in power.

## The shop: Adena

Gross Adena earned from monsters, by the level reached. Each figure is the range across sets.
Talking Island sits at the low end from level 16, because its ground tops out at level 17.

| Level | 5 | 10 | 12 | 14 | 15 | 16 | 17 | 18 | 20 |
|---|---|---|---|---|---|---|---|---|---|
| Earned | 2k | 31–34k | 76–80k | 149–161k | 200–216k | 256–283k | 317–355k | 396–442k | 606–648k |

The best kit each path can buy in its village, priced in rules §24. Armour is the best light or magic
chest and legs plus the Necklace of Wisdom, 44,900 for either path.

| Path | Weapon | Shield | Whole kit |
|---|---|---|---|
| Sword 1h | Long Sword 136,000 | Round Shield 7,110 | 188,010 |
| Sword 2h | Zweihander 244,000 | | 288,900 |
| Dagger | Throwing Knife 136,000 | Round Shield 7,110 | 188,010 |
| Bow | Forest Bow 136,000 | | 180,900 |
| Fists (Orc Village) | Cestus 136,000 | | 180,900 |
| Staff 1h | Relic of The Saints 136,000 | Round Shield 7,110 | 188,010 |
| Staff 2h | Journeyman's Staff 136,000 | | 180,900 |

The level each of a path's weapons is first held at, then the level and hunt the whole kit is worn
(the weapon is always the last piece bought), then the Adena still held at level 20:

| Set | Skill | Path | 768 | 12,500 | 54,100 | Top weapon, kit | Hunt | Held at 20 |
|---|---|---|---|---|---|---|---|---|
| Human Fighter | Power Strike | sword 1h | Short Sword 4.0 | Broadsword 10.3 | Gladius 13.0 | Long Sword **15.7** (15–16) | 185 | 381k |
| Human Fighter | Power Strike | sword 2h | Short Sword 3.8 | Broadsword 10.0 | Brandish 13.0 | Zweihander **17.0** (16–18) | 231 | 282k |
| Human Fighter | Mortal Blow | dagger | Bone Dagger 4.0 | Doom Dagger 10.3 | Dirk 13.0 | Throwing Knife **15.7** (15–16) | 186 | 380k |
| Human Fighter | Power Shot | bow | Short Bow 3.8 | Bow 10.0 | Hunting Bow 13.0 | Forest Bow **15.5** (15–16) | 181 | 391k |
| Elven Fighter | Power Shot | bow | (kit) | Bow 9.9 | Hunting Bow 13.0 | Forest Bow **15.1** (15–16) | 201 | 417k |
| Dark Fighter | Mortal Blow | dagger | Bone Dagger 4.3 | Doom Dagger 10.4 | Dirk 13.0 | Throwing Knife **15.2** (15–16) | 198 | 388k |
| Orc Fighter | Iron Punch | fists | Spiked Gloves 3.9 | Iron Gloves 10.0 | Fox Claw Gloves 13.0 | Cestus **15.3** (15–16) | 188 | 393k |
| Orc Fighter | Power Strike | sword 1h | Short Sword 4.2 | Broadsword 10.4 | Gladius 13.0 | Long Sword **15.7** (15–16) | 193 | 384k |
| Orc Fighter | Power Strike | sword 2h | Short Sword 4.0 | Broadsword 10.0 | Brandish 13.0 | Zweihander **17.0** (16–18) | 246 | 285k |
| Human Mystic | | staff 1h | Rod 4.1 | Spellbook 10.3 | | Relic **14.9** (14–16) | 162 | 405k |
| Human Mystic | | staff 2h | Rod 3.8 | Willow Staff 9.9 | Cedar Staff 13.0 | Journeyman's **15.4** (15–16) | 181 | 390k |
| Elven Mystic | | staff 1h | Rod 4.2 | Spellbook 10.3 | | Relic **14.8** (14–15) | 178 | 435k |
| Elven Mystic | | staff 2h | Rod 3.9 | Willow Staff 9.9 | Cedar Staff 13.0 | Journeyman's **15.1** (15–16) | 201 | 418k |
| Dark Mystic | | staff 1h | Rod 4.3 | Spellbook 10.3 | | Relic **14.7** (14–15) | 171 | 417k |
| Dark Mystic | | staff 2h | Rod 4.0 | Willow Staff 10.0 | Cedar Staff 13.0 | Journeyman's **15.1** (15–16) | 192 | 397k |
| Orc Mystic | | staff 1h | Rod 4.2 | Spellbook 10.3 | | Relic **14.9** (14–16) | 167 | 411k |
| Orc Mystic | | staff 2h | Rod 4.0 | Willow Staff 10.0 | Cedar Staff 13.0 | Journeyman's **15.3** (15–16) | 188 | 392k |

- **Every path reaches each weapon tier at the same levels: about 4, 10, 13, and 15 to 16 for the
  top.** Armour is cheap enough that the top weapon is always the last thing a kit needs.
- **Buying every tier on the way costs about half a level.** A player who saved everything would own
  a 181,000 to 188,000 kit at about level 14.7, and the Zweihander's at about 16.5. Selling the old
  weapon back for half doesn't make up the difference. A Mystic's one-handed path finishes first
  because it has no 54,100 tier, so it saves without meaning to.
- **The Zweihander is the only long goal.** It costs 244,000 against 136,000 for every other top
  weapon, and it is the one path where saving pays off.
- **From level 15 to 17, the shop has nothing left but potions.** Adena keeps coming at 50,000 to
  90,000 a level, and a player reaches 20 holding 290,000 to 430,000. Gludio's D-grade gear will be
  bought with that, so price it against these figures, or give the village something to spend it on
  sooner.

## Time to level 20

Minutes of play to level 20 at the defaults, resting and fighting: before the fight had distance
(`30e1576`), once it had (`58c1d4c`), and now, with the first skills where Lineage II taught them.
Each step is compared run for run (`bench/compare.exs`).

| Set | Path | Before distance | With distance | Now |
|---|---|---|---|---|
| Human Fighter | sword 1h / 2h / dagger | 198 / 195 / 198 | 207 / 203 / 207 | 208 / 204 / 207 |
| Human Fighter | bow | 228 | 208 | 208 |
| Human Mystic | staff 1h / 2h | 207 / 215 | 191 / 191 | 191 / 191 |
| Elven Fighter | bow | 233 | 216 | 217 |
| Elven Mystic | staff 1h / 2h | 220 / 223 | 204 / 205 | 202 / 202 |
| Dark Fighter | dagger | 241 | 230 | 230 |
| Dark Mystic | staff 1h / 2h | 321 / 324 | 338 / 338 | **265 / 266** |
| Orc Fighter | fists / sword 1h / 2h | 264 / 280 / 262 | 271 / 286 / 269 | 268 / 281 / 266 |
| Orc Mystic | staff 1h / 2h | 312 / 312 | 309 / 309 | 308 / 308 |

- **A spell or a bow pulls from afar**, so the Human and Elven Mystics and the two archers reach 20
  sooner than before the fight had distance: their first spell or shot is free, and a melee monster
  spends rounds running in. **A melee Fighter pays 2% to 5%**, waiting while an aggressive monster
  runs at it and taking its first blow.
- **The Dark Mystic opens with Wind Strike** and learns Vampiric Touch at 14, as in Lineage II, and
  reaches 20 22% sooner. Its time was resting, not fighting (207 minutes of 338): Vampiric Touch
  cost 25 MP a cast where Wind Strike costs 9. The Elven Mystic's Wind Strike at 1 makes it 1%
  faster, and a Fighter's first skill at 5 costs nothing measurable.
- **The Orc Mystic is now the slowest set** at 308 minutes, resting 205 of them: its WIT gives the
  slowest Casting Spd., Chill Flame burns three rounds after it is begun, and Life Drain costs 27
  MP. The spread from fastest to slowest set narrows from 147 to 117 minutes. Left unused by the
  battle orders (rules §20), Life Drain saves it 10% resting to full and 21% with potions, but it is
  the set's healing, and without potions nearly every run dies; Soul Cry left unused saves about 9%
  at little risk.
- **The Orc Mystic has no Venom.** It was never cast: a poison comes only while the spells rest, and
  Chill Flame or Life Drain is always ready. Without it the set is 0.4% faster for its SP, finishes
  its list at level 14 for 7,840 SP, and its level 7 lines are back at Lineage II's 520.
- **With potions and resting below half**, the Mystics took 11% to 13% longer once the fight had
  distance, since a fight lasts longer once a spell lands late, and buy far fewer potions.

## Survival

The bench at its defaults rests to full before every hunt, so survival is read with no potions and
resting only once a bar falls below a share: `bench/ladder.exs 400 20 <share> 0`. Deaths of 400 runs
a path before the fight had distance (`30e1576`) and now:

| Set | Path | Rest below 50% | Rest below 30% | Most often killed by now |
|---|---|---|---|---|
| Human Mystic | staff 1h / 2h | 14 / 18 to **0 / 0** | 27 / 32 to **0 / 0** | |
| Elven Mystic | staff 1h / 2h | 238 / 370 to **0 / 0** | 249 / 359 to **0 / 0** | |
| Dark Mystic | staff 1h / 2h | 127 / 330 to **3 / 25** | 279 / 397 to **14 / 26** | Skeleton Hunter, Balor Orc Fighters |
| Orc Mystic | staff 1h / 2h | 2 / 7 to 6 / 27 | 109 / 171 to **57 / 110** | Skeleton Longbowman |
| Human Fighter | bow | 365 to **113** | 400 to 388 | Blade Spider |
| Elven Fighter | bow | 400 to **225** | 400 to 399 | Sukar Wererat Leader |
| Dark Fighter | dagger | 235 to **121** | 400 to 385 | Green Fungus, Doom Soldier |
| Human Fighter | sword 1h / 2h / dagger | 8 / 156 / 217 to 6 / 141 / 214 | 347 / 397 / 399 to 346 / 394 / 399 | Blade Spider |
| Orc Fighter | fists | 240 to 258 | 400 to 399 | Skeleton Longbowman |
| Orc Fighter | sword 1h / 2h | 384 / 339 to **294 / 206** | 400 | Skeleton Longbowman, Evil Eyes |

- **Fighting from afar keeps a Mystic alive**, and an archer too. A heal before the pull (rules §20)
  starts each fight topped up, and the opening spell lands before the monster has come.
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
  whole fight from afar and cost the Orc Mystic 20% (it now lights once its blows reach); auras
  raised before the pull, which changed nothing, since an aura outlasts many fights; curses only
  while the monster is still running in, 2% to 3% faster for the Dark Mystic but its Wind Shackle
  was what held a monster off it in melee, so its deaths more than doubled; Ice Bolt slowing the
  run alone, as in Lineage II, which let the Sukar Wererat Leader kill the Elven Mystic at level 19 in 256 to 360 runs
  of 400 without potions; the Orc Mystic with Soul Cry alone until Chill Flame at 7, as in
  Lineage II, which died at levels 2 to 7 even resting to full (59 runs of 400) and took 20% longer;
  and a poison cast before the spells, while the monster is above half or only while it runs in,
  which slowed the Orc Mystic 21% and the Dark Mystic 6% to 13%, since a poison is slow damage that
  cannot take the last HP, bought with a 4-second cast.
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
- **The bench once killed the Orc Fighter with a sword** at levels 3 to 5, 38 runs of 400 with
  potions: its paths counted only the village's stock as their weapons, so the sword path never
  wielded the Squire's Sword it starts with, and a Leather Shield bought early took off its
  two-handed Training Gloves. A path now counts its set's starting weapons, and that set dies none.

## Both together

The trainer and the shop run out at the same point, about hunt 155 to 250 and level 15 to 17. From
there to level 20, a run has nothing to buy and only the level to climb. That stretch is where the
class change, the Temple's buffs, and Gludio's first ground and shops will matter most.
