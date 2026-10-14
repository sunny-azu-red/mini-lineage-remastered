# Mini-Lineage: balance, measured

What the village ladder costs and pays, read off `bench/ladder.exs`. The rules (`docs/rules.md`) say
what things cost; this says when a player can afford them. Every figure here was measured, never
worked out by hand, and holds only for the rules it was measured against.

**Measured at** `ed9c030` (rules §1 to §26), 40 seeded runs of every set up its village's ladder to
level 20, once per weapon path its skills can use: 680 runs, none of them died. Read again at 400
runs a path with each run seeded on its own (`82e8c4d`), one Orc Fighter run in 400, with a sword
and shield, dies at the defaults. Rules §20's battle orders change nothing at the defaults, figure
for figure; what they change is under Survival.

**Rerun it** after anything that moves a fight's numbers, a price, a monster's SP or Adena, or the
trainer's list, and rewrite these tables from what it prints (seconds, its runs in parallel):

    MIX_ENV=test mix run --no-start bench/ladder.exs [runs] [top level] [rest below %] [potions kept] [--json path]

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

## Survival

The bench at its defaults rests to full before every hunt, so survival is read with no potions and
resting only once a bar falls below a share: `bench/ladder.exs 400 20 <share> 0`. Deaths of 400 runs
a path, before rules §20's battle orders (`82e8c4d`) and with them at their start, healing before the
pull below 50% and in the fight below 50%:

| Set | Path | Rest below 50% | Rest below 30% | Most often killed by, at 30% |
|---|---|---|---|---|
| Human Mystic | staff 1h / 2h | 14 / 18, the same | 385 / 393 to **27 / 32** | Orc Fighter Leader, Talon Spider |
| Elven Mystic | staff 1h / 2h | 238 / 370, the same | 400 / 400 to **249 / 359** | Shade Horror, Mist Terror |
| Dark Mystic | staff 1h / 2h | 127 / 330, the same | 395 / 400 to **279 / 397** | Omen Beast, Cave Fang Spider |
| Orc Mystic | staff 1h / 2h | 2 / 7 | 109 / 171 | Kasha Timber Wolf |
| Elven Fighter | bow | 400 | 400 | Dungeon Skeleton |
| Human Fighter | sword 1h / 2h / dagger / bow | 8 / 156 / 217 / 365 | 347 / 397 / 399 / 400 | Blade Spider, Orc Fighter Leader |
| Dark Fighter | dagger | 235 | 400 | Balor Orc Fighter |
| Orc Fighter | fists / sword 1h / 2h | 240 / 384 / 339 | 400 | Evil Eye |

- **A heal before the pull keeps a Mystic alive between rests.** Nothing rests on the ground (§11),
  so a run that walks on below half used to begin every fight with what the last one left. Run for
  run, it reaches level 20 in the same time: the Human Mystic's 14 runs that finished both ways took
  184.7 and 184.6 minutes.
- **Resting below half leaves it nothing to do,** since the pull's heal waits for the same line, and
  so the bench resting at 50% reads the same before and after. It is the player who walks on past
  half that the order saves.
- **Three other ways were measured and dropped.** A heal put before the spells in the fight, alone
  or taking turns with them, killed every Human and Elven Mystic run, because its 3 rounds of
  casting mend less than the monster deals in them. Heals after the kill and before the pull, to
  full, kept Mystics alive but slowed them 16% to 70% to level 20, spending MP that resting then had
  to give back, and MP rests slower than HP.
- **The Elven Fighter's Elemental Heal** (71 HP for 40 MP) does not save it at either share: it dies
  to the Elven Fortress's skeletons as before.
- **The Fighters without a heal die as they did**, and the Orc Fighter with a sword dies even with
  potions (35 of 400 resting below half), and once in 400 at the defaults. That predates the orders.

## Both together

The trainer and the shop run out at the same point, about hunt 155 to 250 and level 15 to 17. From
there to level 20, a run has nothing to buy and only the level to climb. That stretch is where the
class change, the Temple's buffs, and Gludio's first ground and shops will matter most.
