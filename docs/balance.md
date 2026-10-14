# Mini-Lineage: balance, measured

What the village ladder costs and pays, read off `bench/ladder.exs`. The rules (`docs/rules.md`) say
what things cost; this says when a player can afford them. Every figure here was measured, never
worked out by hand, and holds only for the rules it was measured against.

**Measured at** `ed9c030` (rules §1 to §26), 40 seeded runs of every set up its village's ladder to
level 20, once per weapon path its skills can use: 680 runs, none of them died. The trainer's and
the shop's tables are that reading, and still hold: a kill pays what it paid, so SP and Adena by
level and hunt are unmoved by how a fight is fought. **Time to level 20 and Survival** are read at
400 runs a path with each run seeded on its own, on the fight of rules §20 as it now stands: a line
between the two, spells that take effect as their cast ends, and the battle orders.

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
| Human Fighter | 3 (12) | 15,440 | 16 | 209 of 347 | 17,100 |
| Elven Fighter | 3 (7) | 11,800 | 15.2 (15–16) | 210 of 414 | 21,200 |
| Dark Fighter | 3 (7) | 11,850 | 16.0 (15–16) | 205 of 395 | 21,000 |
| Orc Fighter | 3 (9) | 11,060 | 15 | 181 of 385 | 21,800 |
| Human Mystic | 3 (7) | 9,010 | 14.8 (14–15) | 155 of 348 | 23,500 |
| Elven Mystic | 4 (10) | 7,890 | 14 | 159 of 413 | 25,100 |
| Dark Mystic | 5 (6) | 9,490 | 15 | 175 of 395 | 23,400 |
| Orc Mystic | 5 (9) | 10,100 | 15 | 170 of 384 | 22,800 |

A tier's lines are taught at one character level (1, 5, 10 and 15 for a Fighter; 1, 7 and 14 for a
Mystic). The wait is how many hunts pass between reaching that level and buying a line taught there,
shown as average / worst:

| Set | Tier 2 | Tier 3 | Tier 4 |
|---|---|---|---|
| Human Fighter | L5: 6 / 15 | L10: 20 / 41 | L15: 26 / 57 |
| Elven Fighter | L5: 5 / 11 | L10: 0 / 0 | L15: 12 / 39 |
| Dark Fighter | L5: 1 / 3 | L10: 4 / 10 | L15: 15 / 39 |
| Orc Fighter | L5: 8 / 20 | L10: 20 / 35 | L15: 11 / 25 |
| Human Mystic | L7: 9 / 23 | L14: 12 / 27 | |
| Elven Mystic | L7: 10 / 31 | L14: 6 / 22 | |
| Dark Mystic | L7: 13 / 21 | L14: 20 / 42 | |
| Orc Mystic | L7: 13 / 25 | L14: 13 / 41 | |

- **No tier is empty, and every set can afford its whole list.** Each tier's first line can be bought
  on arrival. Two tiers hold a single line, the Elven Fighter's at 10 (Power Shot 3) and the Dark
  Fighter's at 5 (Mortal Blow 2), and both are bought at once. Every other tier offers two to five
  lines, so the player chooses the order.
- **The Mystics finish about a level sooner** (14 to 15, against 15 to 16). Their skills have fewer
  steps, and their fights spend MP rather than SP.
- **The Human Fighter pays the most and finishes last.** About half its 15,440 buys Mortal Blow and
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
| Human Fighter | Power Strike | sword 1h | Short Sword 4.2 | Broadsword 10.3 | Gladius 13.0 | Long Sword **15.7** (15–16) | 186 | 369k |
| Human Fighter | Power Strike | sword 2h | Short Sword 3.9 | Broadsword 10.0 | Brandish 13.0 | Zweihander **17.0** (16–18) | 231 | 286k |
| Human Fighter | Mortal Blow | dagger | Bone Dagger 4.2 | Doom Dagger 10.3 | Dirk 13.1 | Throwing Knife **15.8** (15–16) | 186 | 380k |
| Human Fighter | Power Shot | bow | Short Bow 3.8 | Bow 9.9 | Hunting Bow 12.9 | Forest Bow **15.4** (15–16) | 182 | 385k |
| Elven Fighter | Power Shot | bow | (kit) | Bow 9.9 | Hunting Bow 12.9 | Forest Bow **15.2** (15–16) | 202 | 415k |
| Dark Fighter | Mortal Blow | dagger | Bone Dagger 4.2 | Doom Dagger 10.4 | Dirk 13.0 | Throwing Knife **15.2** (15–16) | 199 | 382k |
| Orc Fighter | Iron Punch | fists | Spiked Gloves 3.9 | Iron Gloves 10.1 | Fox Claw Gloves 13.0 | Cestus **15.5** (15–16) | 191 | 389k |
| Orc Fighter | Power Strike | sword 1h | Short Sword 4.1 | Broadsword 10.4 | Gladius 13.1 | Long Sword **15.7** (15–16) | 195 | 380k |
| Orc Fighter | Power Strike | sword 2h | Short Sword 4.1 | Broadsword 9.9 | Brandish 13.0 | Zweihander **16.9** (16–17) | 246 | 288k |
| Human Mystic | | staff 1h | Rod 4.0 | Spellbook 10.3 | | Relic **14.9** (14–15) | 163 | 407k |
| Human Mystic | | staff 2h | Rod 3.8 | Willow Staff 9.8 | Cedar Staff 12.9 | Journeyman's **15.5** (15–16) | 182 | 384k |
| Elven Mystic | | staff 1h | Rod 4.2 | Spellbook 10.3 | | Relic **14.8** (14–15) | 178 | 427k |
| Elven Mystic | | staff 2h | Rod 4.0 | Willow Staff 10.1 | Cedar Staff 12.9 | Journeyman's **15.1** (15–16) | 200 | 416k |
| Dark Mystic | | staff 1h | Rod 4.3 | Spellbook 10.3 | | Relic **14.7** (14–15) | 170 | 412k |
| Dark Mystic | | staff 2h | Rod 4.0 | Willow Staff 10.0 | Cedar Staff 12.9 | Journeyman's **15.0** (15–16) | 191 | 394k |
| Orc Mystic | | staff 1h | Rod 4.2 | Spellbook 10.3 | | Relic **14.9** (14–15) | 166 | 406k |
| Orc Mystic | | staff 2h | Rod 4.0 | Willow Staff 9.9 | Cedar Staff 13.0 | Journeyman's **15.1** (15–16) | 186 | 400k |

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

Minutes of play to level 20 at the defaults, resting and fighting, before the fight had distance
(`30e1576`) and now, compared run for run (`bench/compare.exs`).

| Set | Path | Before | Now | Change |
|---|---|---|---|---|
| Human Fighter | sword 1h / 2h / dagger | 198 / 195 / 198 | 207 / 203 / 207 | +4% |
| Human Fighter | bow | 228 | 208 | −9% |
| Human Mystic | staff 1h / 2h | 207 / 215 | 191 / 191 | −8% / −11% |
| Elven Fighter | bow | 233 | 216 | −7% |
| Elven Mystic | staff 1h / 2h | 220 / 223 | 204 / 205 | −7% / −8% |
| Dark Fighter | dagger | 241 | 230 | −5% |
| Dark Mystic | staff 1h / 2h | 321 / 324 | 338 / 338 | +5% / +4% |
| Orc Fighter | fists / sword 1h / 2h | 264 / 280 / 262 | 271 / 286 / 269 | +2% to +3% |
| Orc Mystic | staff 1h / 2h | 312 / 312 | 309 / 309 | −1% |

- **A spell or a bow now pulls from afar**, so the Human and Elven Mystics and the two archers
  reach 20 sooner: their first spell or shot is free, and a melee monster spends rounds running in.
- **A melee Fighter pays 2% to 5%**, waiting while an aggressive monster runs at it and taking its
  first blow.
- **The Dark and Orc Mystics stay the slowest sets**, as they were. Their spells cast slowly (the Orc
  Mystic's WIT gives the slowest Casting Spd.) and rest long, and a spell that takes effect as its
  cast ends costs them most: the Orc Mystic's Chill Flame burns three rounds later than it did, and
  the Dark Mystic's Vampiric Touch rests 12 seconds. The spread from fastest to slowest set widens
  from 129 to 147 minutes. Their kits are the next thing to look at.
- **With potions and resting below half**, the Mystics take 11% to 13% longer than before, since a
  fight lasts longer once a spell lands late, and buy far fewer potions.

## Survival

The bench at its defaults rests to full before every hunt, so survival is read with no potions and
resting only once a bar falls below a share: `bench/ladder.exs 400 20 <share> 0`. Deaths of 400 runs
a path before the fight had distance (`30e1576`) and now:

| Set | Path | Rest below 50% | Rest below 30% | Most often killed by now |
|---|---|---|---|---|
| Human Mystic | staff 1h / 2h | 14 / 18 to **0 / 0** | 27 / 32 to **0 / 0** | |
| Elven Mystic | staff 1h / 2h | 238 / 370 to **2 / 5** | 249 / 359 to **2 / 5** | Sukar Wererat Leader |
| Dark Mystic | staff 1h / 2h | 127 / 330 to **7 / 13** | 279 / 397 to **13 / 18** | Doom Soldier, Omen Beast |
| Orc Mystic | staff 1h / 2h | 2 / 7 to 9 / 16 | 109 / 171 to **63 / 115** | Skeleton Longbowman |
| Human Fighter | bow | 365 to **118** | 400 to 388 | Blade Spider |
| Elven Fighter | bow | 400 to **291** | 400 | Sukar Wererat Leader |
| Dark Fighter | dagger | 235 to **130** | 400 to 378 | Green Fungus, Doom Soldier |
| Human Fighter | sword 1h / 2h / dagger | 8 / 156 / 217, the same | 347 / 397 / 399, the same | Blade Spider |
| Orc Fighter | fists | 240 to **317** | 400 | Skeleton Longbowman, Evil Eye Watcher |
| Orc Fighter | sword 1h / 2h | 384 / 339 to 386 / 344 | 400 | Evil Eye Watcher |

- **Fighting from afar keeps a Mystic alive**, and an archer too. A heal before the pull (rules §20)
  starts each fight topped up, and the opening spell lands before the monster has come.
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
  whole fight from afar and cost the Orc Mystic 20% (it now lights once its blows reach); and auras
  raised before the pull, which changed nothing, since an aura outlasts many fights.
- **The Orc Fighter with a sword** dies once in 400 at the defaults, and 35 times with potions; that
  predates all of this.

## Both together

The trainer and the shop run out at the same point, about hunt 155 to 250 and level 15 to 17. From
there to level 20, a run has nothing to buy and only the level to climb. That stretch is where the
class change, the Temple's buffs, and Gludio's first ground and shops will matter most.
