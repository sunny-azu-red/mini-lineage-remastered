# Mini-Lineage: the base rules

The foundation every other system builds on: what a character is, the stats it has, and the
formulas that turn them into numbers. Each rule has a worked example, and `test/mini_lineage/game/rules_test.exs` holds the code to every example and every table here.

Change a rule here and in the code together, or not at all. New systems (classes, items, fighting,
the world) are planned in `docs/roadmap.md` and build on these rules rather than changing them
quietly.

## 1. A character

A character is one of four races (Human, Elf, Dark Elf, Orc) on one of two paths (Fighter or
Mystic): eight starting sets. A character has a level from 1 to 80, and starts at level 1 with no
Adena.

Each race starts in its own village, and that is where a new character first stands (§14).

| Race | Starting town |
|---|---|
| Human | Talking Island Village |
| Elf | Elven Village |
| Dark Elf | Dark Elf Village |
| Orc | Orc Village |

## 2. The six attributes

| Attribute | What it feeds |
|---|---|
| STR | P.Atk |
| CON | Max HP and HP regen |
| DEX | Accuracy, Evasion, Critical, Atk. Spd. |
| INT | M.Atk |
| WIT | Magic Critical, Casting Spd. |
| MEN | Max MP, MP regen and M.Def |

## 3. Starting attributes

| Set | Race | Path | STR | CON | DEX | INT | WIT | MEN |
|---|---|---|---|---|---|---|---|---|
| Human Fighter | Human | Fighter | 40 | 43 | 30 | 21 | 11 | 25 |
| Human Mystic | Human | Mystic | 22 | 27 | 21 | 41 | 20 | 39 |
| Elven Fighter | Elf | Fighter | 36 | 36 | 35 | 23 | 14 | 26 |
| Elven Mystic | Elf | Mystic | 21 | 25 | 24 | 37 | 23 | 40 |
| Dark Fighter | Dark Elf | Fighter | 41 | 32 | 34 | 25 | 12 | 26 |
| Dark Mystic | Dark Elf | Mystic | 23 | 24 | 23 | 44 | 19 | 37 |
| Orc Fighter | Orc | Fighter | 40 | 47 | 26 | 18 | 12 | 27 |
| Orc Mystic | Orc | Mystic | 27 | 31 | 24 | 31 | 15 | 42 |

## 4. Attribute bonus

An attribute is worth a bonus: **bonus = growth ^ (value − pivot)**, rounded to two decimals. A value
counts as 1 to 99.

| Attribute | Growth | Pivot | at 20 | at 30 | at 40 | at 50 |
|---|---|---|---|---|---|---|
| STR | 1.036 | 34.845 | 0.59 | 0.84 | 1.20 | 1.71 |
| CON | 1.030 | 27.632 | 0.80 | 1.07 | 1.44 | 1.94 |
| DEX | 1.009 | 19.36 | 1.01 | 1.10 | 1.20 | 1.32 |
| INT | 1.020 | 31.375 | 0.80 | 0.97 | 1.19 | 1.45 |
| WIT | 1.050 | 20 | 1.00 | 1.63 | 2.65 | 4.32 |
| MEN | 1.010 | -0.06 | 1.22 | 1.35 | 1.49 | 1.65 |

Example: a Human Fighter's STR 40 is worth ×1.20.

## 5. Level bonus

**level bonus = (level + 89) ÷ 100**

Example: ×0.90 at level 1, ×1.69 at level 80.

## 6. Max HP and Max MP

Each set starts at a value and gains a little more with every level:

**grown = start + gain × (L − 1) + growth × (L − 1) × (L − 2) ÷ 2**

**Max HP = grown HP × CON bonus**, and **Max MP = grown MP × MEN bonus**, both rounded down.

| Set | HP start | HP gain | HP growth | MP start | MP gain | MP growth |
|---|---|---|---|---|---|---|
| Human Fighter | 80 | 11.83 | 0.13 | 30 | 5.46 | 0.06 |
| Human Mystic | 101 | 15.47 | 0.17 | 40 | 7.28 | 0.08 |
| Elven Fighter | 89 | 12.74 | 0.14 | 30 | 5.46 | 0.06 |
| Elven Mystic | 104 | 15.47 | 0.17 | 40 | 7.28 | 0.08 |
| Dark Fighter | 94 | 13.65 | 0.15 | 30 | 5.46 | 0.06 |
| Dark Mystic | 106 | 15.47 | 0.17 | 40 | 7.28 | 0.08 |
| Orc Fighter | 80 | 12.74 | 0.14 | 30 | 5.46 | 0.06 |
| Orc Mystic | 95 | 15.47 | 0.17 | 40 | 7.28 | 0.08 |

Example: a Human Fighter grows to 327 HP by level 20, × 1.58 for CON 43 = **516 Max HP**. It has
126 at level 1, 1,007 at 40 and 2,235 at 80.

## 7. Power

Each path starts with a power, a magic, a body and a mind. Anything added later, such as gear, adds
to them.

| Path | Power | Magic | Body | Mind |
|---|---|---|---|---|
| Fighter | 4 | 6 | 80 | 41 |
| Mystic | 3 | 6 | 54 | 41 |

- **P.Atk = power × STR bonus × level bonus**
- **M.Atk = magic × INT bonus² × level bonus²**
- **P.Def = body × level bonus**
- **M.Def = mind × MEN bonus × level bonus**

Example: a level 1 Human Fighter has P.Atk 4 × 1.20 × 0.90 = **4.32**, P.Def 80 × 0.90 = **72** and
M.Def 41 × 1.28 × 0.90 = **47.2**. A level 1 Human Mystic has M.Atk 6 × 1.21² × 0.90² = **7.1**.

## 8. Accuracy and Evasion

**Accuracy = Evasion = √DEX × 6 + level**, rounded.

Example: a level 1 Human Fighter, DEX 30: √30 × 6 + 1 = **34**.

## 9. Critical

- **Critical % = 4 × DEX bonus**, at most 50%.
- **Magic Critical % = 0.8 × WIT bonus**, at most 20%.

Example: a Human Fighter's DEX 30 gives 4 × 1.10 = **4.4%**. A Human Mystic's WIT 20 gives
0.8 × 1.00 = **0.8%**.

## 10. Speed

- **Atk. Spd. = 300 × DEX bonus**, rounded down, at most 1500.
- **Casting Spd. = 333 × WIT bonus**, rounded down, at most 1999.
- In a fight, a character strikes **Atk. Spd. ÷ 300** times a round and casts **Casting Spd. ÷ 333**
  times a round. A fraction carries over to the next round.

Example: a Human Fighter's DEX 30 gives Atk. Spd. **330**, so **1.1** blows a round.

## 11. Resting

Out of combat, a character gets HP and MP back every 3 seconds. In combat, nothing.

- **HP per tick = base × level bonus × CON bonus × 3**, where base is 1.5 + level ÷ 20 below level 11,
  and 1.4 + level ÷ 10 from level 11.
- **MP per tick = (0.87 + 0.03 × level) × level bonus × MEN bonus × 3**
- Each is rounded to the nearest whole point, a half rounding up, since HP and MP are whole.

Example: a level 1 Human Fighter rests 1.55 × 0.90 × 1.58 × 3 = 6.6, so **7 HP** a tick, and its
126 HP fill in 18 ticks, under a minute. At level 40 it rests **33 HP** a tick and fills 1,007 HP in
31 ticks, about a minute and a half.

## 12. Levels

A character starts at level 1 with 0 EXP and reaches each level at the EXP below. Level 80 is the
last. Reaching a level refills HP and MP.

| Levels | EXP |
|---|---|
| 1–10 | 0, 68, 363, 1168, 2884, 6038, 11287, 19423, 31378, 48229 |
| 11–20 | 71201, 101676, 141192, 191452, 254327, 331864, 426284, 539995, 675590, 835854 |
| 21–30 | 1023775, 1242536, 1495531, 1786365, 2118860, 2497059, 2925229, 3407873, 3949727, 4555766 |
| 31–40 | 5231213, 5981539, 6812472, 7729999, 8740372, 9850111, 11066012, 12395149, 13844879, 15422851 |
| 41–50 | 17137002, 18995573, 21007103, 23180442, 25524751, 28049509, 30764519, 33679907, 36806133, 40153995 |
| 51–60 | 45524865, 51262204, 57383682, 63907585, 70852742, 80700339, 91162131, 102265326, 114038008, 126509030 |
| 61–70 | 146307211, 167243291, 189363788, 212716741, 237351413, 271973532, 308441375, 346825235, 387197529, 429632402 |
| 71–80 | 474205751, 532692055, 606319094, 696376867, 804219972, 931275828, 1151275834, 1511275834, 2099275834, 4200000000 |

## 13. The base outcomes

How the stats meet each other. The fight builds on these.

- **Hit chance % = 88 + 2 × (Accuracy − Evasion)**, between 28% and 98%.
- **A critical hit** is rolled against Critical %, and doubles the damage.
- **Physical damage = 70 × P.Atk ÷ P.Def**, then ±10%, at least 1.
- **Magic damage = 91 × power × √M.Atk ÷ M.Def**, at least 1. A magic critical is ×4.

Example: Accuracy 40 against Evasion 34 hits **100% → 98%**. P.Atk 100 against P.Def 70 deals
**100** before the ±10%, and **200** on a critical. A spell of power 10 with M.Atk 100 against M.Def 91
deals **100**, and **400** on a magic critical.

## 14. The world

A character stands in one town at a time, which starts as its race's village (§1). The towns:

| Town | Slug | Open |
|---|---|---|
| Talking Island Village | talking-island | yes |
| Elven Village | elven-village | yes |
| Dark Elf Village | dark-elf-village | yes |
| Orc Village | orc-village | yes |
| Town of Gludio | gludio | yes |
| Town of Dion | dion | yes |
| Town of Giran | giran | not yet |
| Giran Harbor | giran-harbor | not yet |

Every town has a Gatekeeper, who sends a character along a route for Adena. A route runs both ways
at one fee, and these are the only routes: the four villages never link to each other, only to
Gludio, and the mainland goes on from there. A town that is not open yet is listed by its
Gatekeeper and cannot be travelled to. A character who cannot pay the fee does not go.

| Between | And | Fee |
|---|---|---|
| Town of Gludio | Town of Dion | 4,100 |
| Talking Island Village | Town of Gludio | 2,900 |
| Elven Village | Town of Gludio | 3,700 |
| Dark Elf Village | Town of Gludio | 3,700 |
| Orc Village | Town of Gludio | 6,000 |
| Town of Dion | Town of Giran | 8,100 |
| Town of Dion | Giran Harbor | 6,500 |

Gludin Village and the boats are left out on purpose: every village goes straight to the Town of
Gludio. The fees are the game's own, not Lineage II's, and will be tuned once the balance can be
seen. `docs/canon/README.md` lists both among its departures.

Example: an Elf goes from Elven Village to Dion through Gludio, for 3,700 + 4,100 = **7,800**
Adena. An Orc with 10,000 reaches Gludio with **4,000** left, which is not enough for Dion.

## 15. Day and night

Night runs from **22:00 to 06:00** in the game's time zone, Europe/Bucharest. The game keeps every
time in UTC, and the zone only decides which hours those are, summer time included. At night every
character's **Accuracy is −3**, which is 6% less to hit by §13.

Example: a level 1 Human Fighter's Accuracy is 34 by day and **31** at night.

## 16. Race perks

Each race answers the world in its own way, and a perk holds only for its own race.

| Perk | Race | When it holds | Effect |
|---|---|---|---|
| Shadow Sense | Dark Elf | at night | Accuracy +3 |
| Blessing of the Mother Tree | Elf | in Elven Village | HP and MP per tick ×1.5 |

- **Shadow Sense** is night vision. A Dark Elf takes night's −3 like everyone else and gains +3
  back, so at night it keeps its daytime Accuracy while everyone else loses 3.
- **The Mother Tree** blesses an Elf that stands beneath it and nobody else: an Elf away from
  Elven Village rests at §11's rate, and so does any other race inside it. The ×1.5 is applied
  before §11 rounds.
- **Orcs** shrug off sleep, root and poison, which have no numbers until there is anything that
  sleeps, roots or poisons.
- **Humans** have no perk. Their strength is having the most class choices.

Example: a level 1 Dark Fighter (DEX 34) has Accuracy 36 by day and 36 − 3 + 3 = **36** at night,
while a level 1 Human Fighter's 34 drops to **31**. A level 1 Elven Fighter rests 5.36 HP and 3.16
MP a tick anywhere else, so 5 and 3, and in Elven Village 8.04 and 4.74, so **8 HP** and **5 MP**.


## 17. Hunting grounds

Each starting village has one hunting ground, reached on foot from the village and for free. It is
a ladder from level 1 to about where the Town of Gludio's grounds begin, carrying one name and every
monster around that village, its fields and its nearby grounds, each at its own level (§18).

| Ground | Town | Slug | Monsters |
|---|---|---|---|
| Obelisk of Victory | Talking Island Village | obelisk-of-victory | Young Keltir, Bearded Keltir, Elpy, Gremlin, Elder Keltir, Wolf, Elder Wolf, Giant Toad, Orc, Orc Grunt, Goblin Scout, Orc Archer, Werewolf, Orc Fighter, Werewolf Hunter, Orc Lieutenant, Werewolf Chieftain, Orc Fighter Leader, Stone Golem, Crasher, Talon Spider, Blade Spider |
| Elven Fortress | Elven Village | elven-fortress | Young Red Keltir, Gremlin, Red Keltir, Elder Red Keltir, Gray Wolf, Goblin Raider, Kaboo Orc, Kaboo Orc Grunt, Green Dryad, Kaboo Orc Archer, Spore Fungus, Kaboo Orc Fighter, Baraq Orc Fighter, Baraq Orc Warrior Leader, Dungeon Skeleton, Dungeon Skeleton Archer, Dread Soldier, Mist Terror, Dark Terror, Shade Horror, Sukar Wererat, Sukar Wererat Leader, Dre Vanul Tracker |
| School of Dark Arts | Dark Elf Village | school-of-dark-arts | Young Brown Keltir, Gremlin, Brown Keltir, Elder Brown Keltir, Ashen Wolf, Goblin, Imp, Imp Elder, Balor Orc Archer, Goblin Lookout, Green Fungus, Balor Orc Fighter, Goblin Thief, Vaiss Orc, Balor Orc Lieutenant, Vaiss Orc Warrior Leader, Balor Orc Fighter Leader, Blood Fungus, Skeleton Hunter, Doom Soldier, Cave Spider, Cave Fang Spider, Omen Beast, Tainted Zombie, Stink Zombie, Lesser Succubus, Lesser Succubus Turen, Lesser Succubus Tilfo |
| Cave of Trials | Orc Village | cave-of-trials | Young Prairie Keltir, Gremlin, Prairie Keltir, Elder Prairie Keltir, Kasha Wolf, Goblin Grave Robber, Rakeclaw Imp, Kasha Timber Wolf, Rakeclaw Imp Hunter, Mountain Fungus, Maraku Werewolf, Evil Eye, Evil Eye Watcher, Darkwing Bat, Grizzly, Goblin Tomb Raider Leader, Slave Skeleton, Greystone Golem, Grave Keeper, Evil Eye Patroller, Crypt Horror, Kuruka Ratman, Kuruka Ratman Hunter, Skeleton Longbowman, Undead Slave, Ghost, Ghost Guardian |

## 18. Monsters

A monster is what Lineage II made it, taken whole from `docs/canon/monsters.md` (L2J's figures).
Its Accuracy and Evasion are √DEX × 6 + its level, rounded, and its Critical is 4 × its DEX bonus,
as a character's are (§8, §9). A monster carries its Adena at the chance given, evenly anywhere from
the least to the most. The spells are §19's.

| Monster | Level | HP | MP | P.Atk | M.Atk | P.Def | M.Def | Atk. Spd. | DEX | EXP | SP | Adena | Spells |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Young Keltir | 1 | 62 | 44 | 9 | 3 | 39 | 32 | 278 | 30 | 35 | 2 | 8–12 at 70% |  |
| Bearded Keltir | 1 | 62 | 44 | 9 | 3 | 39 | 32 | 278 | 30 | 35 | 2 | 8–12 at 70% |  |
| Elpy | 1 | 62 | 44 | 9 | 3 | 39 | 32 | 278 | 30 | 35 | 2 | 8–12 at 70% |  |
| Gremlin | 1 | 62 | 44 | 9 | 3 | 39 | 32 | 278 | 30 | 29 | 2 | 7–13 at 100% |  |
| Elder Keltir | 3 | 90 | 60 | 12 | 3 | 40 | 35 | 278 | 30 | 105 | 2 | 13–20 at 70% |  |
| Wolf | 4 | 107 | 68 | 12 | 4 | 46 | 37 | 278 | 30 | 141 | 4 | 19–29 at 70% |  |
| Elder Wolf | 5 | 126 | 77 | 13 | 4 | 48 | 39 | 278 | 30 | 176 | 5 | 30–42 at 70% |  |
| Giant Toad | 5 | 126 | 77 | 13 | 4 | 48 | 39 | 278 | 30 | 178 | 5 | 30–42 at 70% |  |
| Orc | 6 | 147 | 85 | 15 | 5 | 50 | 41 | 278 | 30 | 213 | 6 | 41–58 at 70% |  |
| Orc Grunt | 7 | 171 | 94 | 17 | 6 | 53 | 43 | 278 | 30 | 249 | 8 | 51–72 at 70% |  |
| Goblin Scout | 8 | 197 | 102 | 18 | 6 | 55 | 45 | 278 | 30 | 284 | 10 | 67–91 at 70% |  |
| Orc Archer | 8 | 197 | 102 | 41 | 6 | 55 | 45 | 249 | 30 | 293 | 10 | 69–94 at 70% |  |
| Werewolf | 9 | 226 | 111 | 20 | 7 | 58 | 47 | 278 | 30 | 321 | 11 | 80–108 at 70% |  |
| Orc Fighter | 10 | 257 | 120 | 22 | 8 | 61 | 49 | 278 | 30 | 363 | 12 | 98–132 at 70% |  |
| Werewolf Hunter | 10 | 257 | 120 | 25 | 8 | 55 | 49 | 278 | 30 | 363 | 12 | 98–132 at 70% |  |
| Orc Lieutenant | 11 | 292 | 129 | 23 | 9 | 70 | 52 | 278 | 30 | 391 | 15 | 109–147 at 70% |  |
| Werewolf Chieftain | 12 | 315 | 138 | 30 | 10 | 60 | 54 | 278 | 30 | 436 | 16 | 114–157 at 70% |  |
| Orc Fighter Leader | 12 | 315 | 138 | 30 | 10 | 60 | 54 | 278 | 30 | 447 | 17 | 117–161 at 70% |  |
| Stone Golem | 13 | 339 | 147 | 30 | 11 | 70 | 56 | 278 | 30 | 654 | 26 | 127–180 at 70% | NPC Windstrike - Slow 1 |
| Crasher | 14 | 364 | 156 | 30 | 12 | 80 | 59 | 278 | 30 | 705 | 27 | 128–189 at 70% | NPC Windstrike - Slow 1 |
| Talon Spider | 16 | 417 | 174 | 44 | 15 | 72 | 64 | 278 | 30 | 570 | 23 | 118–183 at 70% |  |
| Blade Spider | 17 | 446 | 184 | 48 | 17 | 75 | 67 | 278 | 30 | 618 | 26 | 122–197 at 70% |  |
| Young Red Keltir | 1 | 62 | 44 | 9 | 3 | 39 | 32 | 278 | 30 | 35 | 2 | 8–12 at 70% |  |
| Red Keltir | 2 | 75 | 52 | 10 | 3 | 42 | 34 | 278 | 30 | 70 | 2 | 8–13 at 70% |  |
| Elder Red Keltir | 3 | 90 | 60 | 11 | 3 | 44 | 35 | 278 | 30 | 105 | 2 | 13–20 at 70% |  |
| Gray Wolf | 4 | 107 | 68 | 12 | 4 | 46 | 37 | 278 | 30 | 141 | 4 | 19–29 at 70% |  |
| Goblin Raider | 5 | 126 | 77 | 13 | 4 | 48 | 39 | 278 | 30 | 178 | 5 | 30–42 at 70% |  |
| Kaboo Orc | 6 | 147 | 85 | 15 | 5 | 50 | 41 | 278 | 30 | 213 | 6 | 41–58 at 70% |  |
| Kaboo Orc Grunt | 7 | 171 | 94 | 17 | 6 | 53 | 43 | 278 | 30 | 249 | 8 | 51–72 at 70% |  |
| Green Dryad | 8 | 197 | 102 | 18 | 6 | 55 | 45 | 278 | 30 | 284 | 10 | 67–91 at 70% |  |
| Kaboo Orc Archer | 8 | 197 | 102 | 41 | 6 | 55 | 45 | 249 | 30 | 293 | 10 | 69–94 at 70% |  |
| Spore Fungus | 9 | 226 | 111 | 22 | 7 | 53 | 47 | 278 | 30 | 321 | 11 | 80–108 at 70% |  |
| Kaboo Orc Fighter | 10 | 257 | 120 | 20 | 8 | 67 | 49 | 278 | 30 | 363 | 12 | 98–132 at 70% |  |
| Baraq Orc Fighter | 10 | 257 | 120 | 25 | 8 | 55 | 49 | 278 | 30 | 302 | 10 | 81–110 at 70% |  |
| Baraq Orc Warrior Leader | 11 | 292 | 129 | 27 | 9 | 58 | 52 | 278 | 30 | 326 | 12 | 91–122 at 70% |  |
| Dungeon Skeleton | 12 | 315 | 138 | 26 | 10 | 60 | 54 | 317 | 30 | 363 | 13 | 95–131 at 70% |  |
| Dungeon Skeleton Archer | 13 | 339 | 147 | 61 | 11 | 77 | 56 | 249 | 30 | 397 | 16 | 97–137 at 70% |  |
| Dread Soldier | 14 | 364 | 156 | 32 | 12 | 66 | 59 | 317 | 30 | 424 | 16 | 97–143 at 70% |  |
| Mist Terror | 15 | 390 | 165 | 40 | 14 | 69 | 62 | 278 | 30 | 454 | 19 | 99–150 at 70% |  |
| Dark Terror | 16 | 417 | 174 | 44 | 15 | 72 | 64 | 278 | 30 | 533 | 22 | 110–171 at 70% |  |
| Shade Horror | 17 | 446 | 184 | 48 | 17 | 75 | 67 | 278 | 30 | 504 | 21 | 100–161 at 70% |  |
| Sukar Wererat | 18 | 476 | 193 | 46 | 19 | 79 | 70 | 317 | 30 | 533 | 23 | 101–167 at 70% |  |
| Sukar Wererat Leader | 19 | 508 | 203 | 42 | 21 | 99 | 73 | 317 | 30 | 576 | 26 | 104–177 at 70% |  |
| Dre Vanul Tracker | 20 | 541 | 213 | 63 | 23 | 86 | 76 | 278 | 30 | 605 | 27 | 106–184 at 70% |  |
| Young Brown Keltir | 1 | 62 | 44 | 9 | 3 | 39 | 32 | 278 | 30 | 35 | 2 | 8–12 at 70% |  |
| Brown Keltir | 2 | 75 | 52 | 10 | 3 | 42 | 34 | 278 | 30 | 70 | 2 | 8–13 at 70% |  |
| Elder Brown Keltir | 3 | 90 | 60 | 11 | 3 | 44 | 35 | 278 | 30 | 105 | 2 | 13–20 at 70% |  |
| Ashen Wolf | 4 | 107 | 68 | 12 | 4 | 46 | 37 | 278 | 30 | 141 | 4 | 19–29 at 70% |  |
| Goblin | 5 | 126 | 77 | 13 | 4 | 48 | 39 | 278 | 30 | 178 | 5 | 30–42 at 70% |  |
| Imp | 6 | 147 | 85 | 15 | 5 | 50 | 41 | 278 | 30 | 213 | 6 | 41–58 at 70% |  |
| Imp Elder | 7 | 171 | 94 | 18 | 6 | 48 | 43 | 278 | 30 | 249 | 8 | 51–72 at 70% |  |
| Balor Orc Archer | 8 | 197 | 102 | 41 | 6 | 55 | 45 | 249 | 30 | 293 | 10 | 69–94 at 70% |  |
| Goblin Lookout | 8 | 197 | 102 | 16 | 6 | 55 | 45 | 317 | 30 | 284 | 10 | 67–91 at 70% |  |
| Green Fungus | 9 | 226 | 111 | 22 | 7 | 53 | 47 | 278 | 30 | 321 | 11 | 80–108 at 70% |  |
| Balor Orc Fighter | 10 | 257 | 120 | 25 | 8 | 55 | 49 | 278 | 30 | 363 | 12 | 98–132 at 70% |  |
| Goblin Thief | 10 | 257 | 120 | 20 | 8 | 61 | 49 | 317 | 30 | 356 | 12 | 96–130 at 70% |  |
| Vaiss Orc | 10 | 257 | 120 | 22 | 8 | 61 | 49 | 278 | 30 | 296 | 10 | 80–108 at 70% |  |
| Balor Orc Lieutenant | 11 | 292 | 129 | 27 | 9 | 58 | 52 | 278 | 30 | 391 | 15 | 109–147 at 70% |  |
| Vaiss Orc Warrior Leader | 11 | 292 | 129 | 27 | 9 | 58 | 52 | 278 | 30 | 326 | 12 | 91–122 at 70% |  |
| Balor Orc Fighter Leader | 12 | 315 | 138 | 30 | 10 | 60 | 54 | 278 | 30 | 436 | 16 | 114–157 at 70% |  |
| Blood Fungus | 12 | 315 | 138 | 30 | 10 | 60 | 54 | 278 | 30 | 427 | 16 | 112–154 at 70% |  |
| Skeleton Hunter | 12 | 315 | 138 | 26 | 10 | 60 | 54 | 317 | 30 | 363 | 13 | 95–131 at 70% |  |
| Doom Soldier | 14 | 364 | 156 | 32 | 12 | 66 | 59 | 317 | 30 | 424 | 16 | 97–143 at 70% |  |
| Cave Spider | 15 | 390 | 165 | 40 | 14 | 69 | 62 | 278 | 30 | 445 | 18 | 97–147 at 70% |  |
| Cave Fang Spider | 16 | 417 | 174 | 44 | 15 | 72 | 64 | 278 | 30 | 485 | 20 | 100–156 at 70% |  |
| Omen Beast | 17 | 446 | 184 | 48 | 17 | 75 | 67 | 278 | 30 | 504 | 21 | 100–161 at 70% |  |
| Tainted Zombie | 18 | 476 | 193 | 44 | 19 | 95 | 70 | 278 | 30 | 754 | 33 | 114–187 at 70% |  |
| Stink Zombie | 19 | 508 | 203 | 48 | 21 | 99 | 73 | 278 | 30 | 799 | 36 | 115–195 at 70% | NPC HP Drain - Slow 1 |
| Lesser Succubus | 20 | 541 | 213 | 57 | 23 | 94 | 76 | 278 | 30 | 605 | 27 | 106–184 at 70% |  |
| Lesser Succubus Turen | 21 | 575 | 227 | 69 | 25 | 89 | 80 | 278 | 30 | 649 | 30 | 110–197 at 70% | NPC HP Drain - Magic 2, NPC Aura Burn - Magic 2 |
| Lesser Succubus Tilfo | 22 | 611 | 242 | 75 | 28 | 93 | 83 | 278 | 30 | 698 | 33 | 116–209 at 70% |  |
| Young Prairie Keltir | 1 | 62 | 44 | 9 | 3 | 39 | 32 | 278 | 30 | 35 | 2 | 8–12 at 70% |  |
| Prairie Keltir | 2 | 75 | 52 | 10 | 3 | 42 | 34 | 278 | 30 | 70 | 2 | 8–13 at 70% |  |
| Elder Prairie Keltir | 3 | 90 | 60 | 11 | 3 | 44 | 35 | 278 | 30 | 105 | 2 | 13–20 at 70% |  |
| Kasha Wolf | 4 | 107 | 68 | 12 | 4 | 46 | 37 | 278 | 30 | 141 | 4 | 19–29 at 70% |  |
| Goblin Grave Robber | 5 | 126 | 77 | 13 | 4 | 48 | 39 | 278 | 30 | 178 | 5 | 30–42 at 70% |  |
| Rakeclaw Imp | 6 | 147 | 85 | 16 | 5 | 46 | 41 | 278 | 30 | 213 | 6 | 41–58 at 70% |  |
| Kasha Timber Wolf | 6 | 147 | 85 | 15 | 5 | 50 | 41 | 278 | 30 | 211 | 6 | 41–58 at 70% |  |
| Rakeclaw Imp Hunter | 7 | 171 | 94 | 18 | 6 | 48 | 43 | 278 | 30 | 249 | 8 | 51–72 at 70% |  |
| Mountain Fungus | 8 | 197 | 102 | 20 | 6 | 50 | 45 | 278 | 30 | 284 | 10 | 67–91 at 70% |  |
| Maraku Werewolf | 9 | 226 | 111 | 22 | 7 | 53 | 47 | 278 | 30 | 321 | 11 | 80–108 at 70% |  |
| Evil Eye | 10 | 257 | 120 | 20 | 8 | 67 | 49 | 278 | 30 | 356 | 12 | 96–130 at 70% | NPC Windstrike - Magic 1, NPC Aura Burn - Magic 1 |
| Evil Eye Watcher | 10 | 257 | 120 | 20 | 8 | 67 | 49 | 278 | 30 | 296 | 10 | 80–108 at 70% | NPC HP Drain - Magic 1, NPC Aura Burn - Magic 1 |
| Darkwing Bat | 11 | 292 | 129 | 27 | 9 | 58 | 52 | 278 | 30 | 391 | 15 | 109–147 at 70% |  |
| Grizzly | 12 | 315 | 138 | 27 | 10 | 66 | 54 | 278 | 30 | 436 | 16 | 114–157 at 70% |  |
| Goblin Tomb Raider Leader | 12 | 315 | 138 | 24 | 10 | 66 | 54 | 317 | 30 | 427 | 16 | 112–154 at 70% |  |
| Slave Skeleton | 12 | 315 | 138 | 26 | 10 | 60 | 54 | 317 | 30 | 363 | 13 | 95–131 at 70% |  |
| Greystone Golem | 13 | 339 | 147 | 27 | 11 | 77 | 56 | 278 | 30 | 654 | 26 | 127–180 at 70% | NPC Prominence - Slow 1 |
| Grave Keeper | 13 | 339 | 147 | 27 | 11 | 77 | 56 | 278 | 30 | 545 | 21 | 106–150 at 70% | NPC Windstrike - Slow 1 |
| Evil Eye Patroller | 14 | 364 | 156 | 30 | 12 | 80 | 59 | 278 | 30 | 498 | 19 | 114–168 at 70% | NPC Windstrike - Magic 1, NPC Aura Burn - Magic 1 |
| Crypt Horror | 15 | 390 | 165 | 40 | 14 | 69 | 62 | 278 | 30 | 454 | 19 | 99–150 at 70% |  |
| Kuruka Ratman | 16 | 417 | 174 | 32 | 15 | 87 | 64 | 317 | 30 | 475 | 19 | 98–153 at 70% |  |
| Kuruka Ratman Hunter | 17 | 446 | 184 | 40 | 17 | 91 | 67 | 278 | 30 | 504 | 21 | 100–161 at 70% |  |
| Skeleton Longbowman | 19 | 508 | 203 | 129 | 21 | 82 | 73 | 249 | 30 | 587 | 26 | 106–181 at 70% |  |
| Undead Slave | 19 | 508 | 203 | 58 | 21 | 82 | 73 | 278 | 30 | 799 | 36 | 115–195 at 70% | NPC Windstrike - Slow 1 |
| Ghost | 20 | 541 | 213 | 63 | 23 | 86 | 76 | 278 | 30 | 599 | 27 | 105–183 at 70% |  |
| Ghost Guardian | 21 | 575 | 227 | 63 | 25 | 98 | 80 | 278 | 30 | 643 | 30 | 109–195 at 70% |  |

Example: a Young Keltir (DEX 30, level 1) has Accuracy and Evasion √30 × 6 + 1 = **34** and a
**4.4%** Critical.

## 19. Skills

Every set starts with one skill from its own tree, and each race's is different. Each costs MP and
then rests for its reuse.

| Skill | Set | Kind | Power | MP | Reuse |
|---|---|---|---|---|---|
| Power Strike | Human Fighter | physical | 25 | 10 | 13,000 |
| Power Shot | Elven Fighter | physical | 65 | 19 | 25,000 |
| Mortal Blow | Dark Fighter | blow | 73 | 9 | 11,000 |
| Iron Punch | Orc Fighter | physical | 29 | 11 | 15,000 |
| Wind Strike | Human Mystic | magic | 12 | 9 | 6,000 |
| Ice Bolt | Elven Mystic | magic | 8 | 9 | 8,000 |
| Vampiric Touch | Dark Mystic | drain | 18 | 25 | 12,000 |
| Chill Flame | Orc Mystic | burn | 20 | 15 | 6,000 |

The reuse is in milliseconds, × 333 ÷ Atk. Spd. for a physical skill or a blow and × 333 ÷
Casting Spd. for the rest.

- **Physical:** 70 × (P.Atk + power) ÷ P.Def, then ±10%. It never misses and never lands a critical.
- **Blow:** the same damage, landing 40% × the DEX bonus of the time, at most 80%, and otherwise
  doing nothing.
- **Magic:** §13's magic damage, which can be a magic critical. A spell never misses.
- **Drain:** magic damage, healing the caster 40% of what the target lost.
- **Burn:** power HP a second for 15 seconds, which never takes the last HP.
- **Ice Bolt** also slows its target for 120 seconds, and a slowed monster swings 30% less.

Monsters cast these:

| Spell | Kind | Power | MP | Reuse |
|---|---|---|---|---|
| NPC Windstrike - Magic 1 | magic | 18 | 7 | 3,000 |
| NPC HP Drain - Magic 1 | drain | 18 | 9 | 3,000 |
| NPC HP Drain - Magic 2 | drain | 26 | 14 | 3,000 |
| NPC Aura Burn - Magic 1 | magic | 5 | 3 | 1,000 |
| NPC Aura Burn - Magic 2 | magic | 7 | 3 | 1,000 |
| NPC Windstrike - Slow 1 | magic | 5 | 13 | 8,000 |
| NPC Windstrike - Slow 2 | magic | 8 | 20 | 8,000 |
| NPC HP Drain - Slow 1 | drain | 5 | 17 | 8,000 |
| NPC Prominence - Slow 1 | magic | 5 | 13 | 8,000 |

A monster's drain heals it 20% of what the character lost.

Example: a level 1 Human Fighter (P.Atk 4.32) strikes a Young Keltir (P.Def 39) with Power Strike
for 70 × (4.32 + 25) ÷ 39 = **52.6** before the ±10%, where a blow does **7.8**. A Dark Fighter's
DEX 34 lands Mortal Blow 40 × 1.14 = **45.6%** of the time. A Human Fighter's Atk. Spd. 330 rests
Power Strike 13,000 × 333 ÷ 330 = **13,118** milliseconds.

## 20. The hunt

One click, one fight. Each village's ground (§17) is hunted from the village, a monster at a time.

- **Who you meet:** one of the ground's monsters within 2 levels of the character, each as likely as
  the next, or one of the nearest if none is that near.
- **A round** is 1⅔ seconds, one blow at 300 Atk. Spd. (Lineage II's 500,000 ÷ Atk. Spd.
  milliseconds). The character acts, then the monster if it still stands, and a skill's reuse runs
  down by 1⅔ seconds each round.
- **The character** swings its blows (§10). A Fighter's skill takes the first blow of a round once its
  reuse has run out and its MP is paid. A Mystic whose spell is ready casts it instead, which takes
  the round, and swings when it is not.
- **The monster** swings its blows the same way, at its own Atk. Spd. A monster with spells casts the
  strongest that is ready instead, which takes the round. Its reuse is not scaled.
- **Blows** hit and do damage as §13 says. Skills and spells do what §19 says.
- **It ends** when either reaches 0 HP. After 1,000 rounds the monster wanders off and pays nothing.
- **The reward** for a kill is the monster's EXP and SP (§12) and its Adena. A character more than 5
  levels above the monster earns × (5 ÷ 6) for each level past the fifth, rounded down.
- **What is left** of HP and MP stays, and rest (§11) goes on refilling it.

Example: a level 12 character who kills a Young Keltir (level 1, 35 EXP) is 11 levels above it, 6 past
the fifth, and earns 35 × (5 ÷ 6)⁶ = 11.7, so **11** EXP. A level 6 character earns all of it.

## 21. Death

At 0 HP the run is over. The character is written as fallen, with what killed it and where, and
nothing of it carries over: the browser goes back to game start for the next one. It keeps its place
on the Monument of Heroes, which ranks every run by EXP and so by level, then EXP, then Adena.

Example: a level 9 run with 40,000 EXP that dies stands above every level 8 run, and above a level 9
run with 39,999 EXP.
