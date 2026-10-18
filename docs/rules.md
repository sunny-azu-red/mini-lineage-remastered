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
| STR | P. Atk. |
| CON | Max HP and HP Recovery |
| DEX | Accuracy, Evasion, Critical, Atk. Spd. |
| INT | M. Atk. |
| WIT | M. Critical, Casting Spd. |
| MEN | Max MP, MP Recovery and M. Def. |

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

**Max HP = grown HP × CON bonus**, and **Max MP = grown MP × MEN bonus**, both rounded down. A
robe's MP (§23) is added to Max MP after that.

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

Each path starts bare-handed and unarmoured, with a power, a magic, a body and a mind. Gear (§23)
takes their place piece by piece: a weapon's P. Atk. and M. Atk. take the place of power and magic, and
each of the three pieces of armour takes the place of its part of the body or the mind.

| Path | Power | Magic | Body | Mind |
|---|---|---|---|---|
| Fighter | 4 | 6 | 80 | 41 |
| Mystic | 3 | 6 | 54 | 41 |

A mini character wears three pieces, and each stands for a whole part of what Lineage II dressed
piece by piece: the chest for head, chest and gloves, the legs for legs and feet, and the necklace
for the necklace, both earrings and both rings. A piece counts for its canon defence × its part's
share ÷ its own slot's share, light armour by a Fighter's shares and a robe by a Mystic's, so a
whole three-piece set is as strong as the matching full set.

| Part | Fighter body | Mystic body | Mind | Light slot | Robe slot | Jewel slot |
|---|---|---|---|---|---|---|
| Chest | 51 | 35 | 0 | 31 | 15 | |
| Legs | 25 | 15 | 0 | 18 | 8 | |
| Necklace | 0 | 0 | 41 | | | 13 |

The last 4 of a body is never covered.

- **P. Atk. = (the weapon's P. Atk., or power) × STR bonus × level bonus**
- **M. Atk. = (the weapon's M. Atk., or magic) × INT bonus² × level bonus²**
- **P. Def. = body, each equipped piece's count in place of its part, × level bonus**
- **M. Def. = mind, the necklace's count in place of its part, × MEN bonus × level bonus**

Example: a level 1 Human Fighter has P. Atk. 4 × 1.20 × 0.90 = **4.32**, P. Def. 80 × 0.90 = **72** and
M. Def. 41 × 1.28 × 0.90 = **47.2**. A level 1 Human Mystic has M. Atk. 6 × 1.21² × 0.90² = **7.1**. In
its starting kit (§23) the Human Fighter has P. Atk. 6 × 1.20 × 0.90 = **6.48** from its Squire's
Sword. Its Squire's Shirt (33) counts for 33 × 51 ÷ 31 = 54.3 and its Squire's Pants (20) for
20 × 25 ÷ 18 = 27.8, so its P. Def. is (80 − 51 − 25 + 54.3 + 27.8) × 0.90 = **77.5**. A Necklace of
Wisdom (25) counts for 25 × 41 ÷ 13 = **78.8** of mind, nearly double the bare 41.

## 8. Accuracy and Evasion

**Accuracy = Evasion = √DEX × 6 + level**, rounded. A weapon's own accuracy (§24) is added to
Accuracy: a dagger or a bow −3, fists +4, a sword 0, and a staff +4, or 0 for a book, a horn or a
relic. A shield's own evasion (§24), −8 for every shield, is added to Evasion while it is worn.

Example: a level 1 Human Fighter, DEX 30: √30 × 6 + 1 = **34**, and with Squire's Gloves **38**
Accuracy. Behind any shield its Evasion is 34 − 8 = **26**.

## 9. Critical

- **Critical % = the weapon's critical (4 bare-handed) × DEX bonus**, at most 50%.
- **M. Critical % = 0.8 × WIT bonus**, at most 20%.

Example: a Human Fighter's DEX 30 gives 4 × 1.10 = **4.4%** bare-handed and 8 × 1.10 = **8.8%** with
a sword. A Human Mystic's WIT 20 gives
0.8 × 1.00 = **0.8%**.

## 10. Speed

- **Atk. Spd. = the weapon's speed (300 bare-handed) × DEX bonus**, rounded down, at most 1500.
- **Casting Spd. = 333 × WIT bonus**, rounded down, at most 1999.
- **Speed = the set's run speed × DEX bonus**, rounded down, the distance it runs a second (§20).
- In a fight, a character strikes **Atk. Spd. ÷ 300** times a round and casts **Casting Spd. ÷ 333**
  times a round. A bow, which draws and then reloads, shoots **Atk. Spd. ÷ 610** times a round
  (Lineage II's 500,000 + 517,500 ÷ Atk. Spd. milliseconds a shot). A fraction carries over to the
  next round.

Example: a Human Fighter's DEX 30 gives Atk. Spd. **330** bare-handed, so **1.1** blows a round, and
379 × 1.10 = **416** with a sword. An Elven Fighter's DEX 35 draws a Squire's Bow at 293 × 1.15 =
**336**, so **0.55** shots a round. The Human Fighter runs 115 × 1.10 = **126**.

| Set | Run speed |
|---|---|
| Human Fighter | 115 |
| Human Mystic | 120 |
| Elven Fighter | 125 |
| Elven Mystic | 122 |
| Dark Fighter | 122 |
| Dark Mystic | 122 |
| Orc Fighter | 117 |
| Orc Mystic | 121 |

## 11. Resting

Out of combat, a character gets HP and MP back every 3 seconds. In combat (§20), nothing.

- **HP per tick = base × level bonus × CON bonus × 3**, where base is 1.5 + level ÷ 20 below level 11,
  and 1.4 + level ÷ 10 from level 11.
- **MP per tick = (0.87 + 0.03 × level) × level bonus × MEN bonus × 3**
- Each is rounded to the nearest whole point, a half rounding up, since HP and MP are whole.
- **Relax** (§19), for a character that knows it: its power in HP more each tick, for its MP, while
  HP is short and the MP lasts.

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
- **Physical damage = 70 × P. Atk. ÷ P. Def.**, then spread by the weapon's own spread (§24) as a whole
  percentage either way, at least 1. Bare hands spread by 5 + √level, rounded down; a monster's
  blows by 10.
- **Magic damage = 91 × power × √M. Atk. ÷ M. Def.**, at least 1. A magic critical is ×4.

Example: Accuracy 40 against Evasion 34 hits **100% → 98%**. P. Atk. 100 against P. Def. 70 deals
**100** before the ±10%, and **200** on a critical. A spell of power 10 with M. Atk. 100 against M. Def. 91
deals **100**, and **400** on a magic critical.

## 14. The world

A character stands in one town at a time, which starts as its race's village (§1). The towns:

| Town | Slug | Open | Gatekeeper |
|---|---|---|---|
| Talking Island Village | talking-island | yes | Roxxy |
| Elven Village | elven-village | yes | Mirabel |
| Dark Elf Village | dark-elf-village | yes | Jasmine |
| Orc Village | orc-village | yes | Tamil |
| Town of Gludio | gludio | yes | Bella |
| Town of Dion | dion | yes | Trisha |
| Town of Giran | giran | not yet | Clarissa |
| Giran Harbor | giran-harbor | not yet | Angelina |

Every town has its Gatekeeper, named above, who sends a character along a route for Adena. A route runs both ways
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

Example: a level 1 Dark Fighter (DEX 34) with its Squire's Dagger (−3, §8) has Accuracy 33 by day and
33 − 3 + 3 = **33** at night, while a level 1 Human Fighter's 34 drops to **31**. A level 1 Elven Fighter rests 5.36 HP and 3.16
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
the least to the most. It fights in melee or with a bow (§10), runs at its run speed, L2J's figure,
which already holds its DEX bonus, and an aggressive one comes at a character it notices (§20). The
spells are §19's.

| Monster | Level | HP | MP | P. Atk. | M. Atk. | P. Def. | M. Def. | Atk. Spd. | DEX | Speed | EXP | SP | Adena | Attack | Aggressive | Spells |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Young Keltir | 1 | 62 | 44 | 9 | 3 | 39 | 32 | 278 | 30 | 121 | 35 | 2 | 8–12 at 70% | melee | no |  |
| Bearded Keltir | 1 | 62 | 44 | 9 | 3 | 39 | 32 | 278 | 30 | 121 | 35 | 2 | 8–12 at 70% | melee | no |  |
| Elpy | 1 | 62 | 44 | 9 | 3 | 39 | 32 | 278 | 30 | 88 | 35 | 2 | 8–12 at 70% | melee | no |  |
| Gremlin | 1 | 62 | 44 | 9 | 3 | 39 | 32 | 278 | 30 | 55 | 29 | 2 | 7–13 at 100% | melee | no |  |
| Elder Keltir | 3 | 90 | 60 | 12 | 3 | 40 | 35 | 278 | 30 | 121 | 105 | 2 | 13–20 at 70% | melee | no |  |
| Wolf | 4 | 107 | 68 | 12 | 4 | 46 | 37 | 278 | 30 | 121 | 141 | 4 | 19–29 at 70% | melee | no |  |
| Elder Wolf | 5 | 126 | 77 | 13 | 4 | 48 | 39 | 278 | 30 | 121 | 176 | 5 | 30–42 at 70% | melee | no |  |
| Giant Toad | 5 | 126 | 77 | 13 | 4 | 48 | 39 | 278 | 30 | 110 | 178 | 5 | 30–42 at 70% | melee | no |  |
| Orc | 6 | 147 | 85 | 15 | 5 | 50 | 41 | 278 | 30 | 121 | 213 | 6 | 41–58 at 70% | melee | no |  |
| Orc Grunt | 7 | 171 | 94 | 17 | 6 | 53 | 43 | 278 | 30 | 121 | 249 | 8 | 51–72 at 70% | melee | no |  |
| Goblin Scout | 8 | 197 | 102 | 18 | 6 | 55 | 45 | 278 | 30 | 121 | 284 | 10 | 67–91 at 70% | melee | no |  |
| Orc Archer | 8 | 197 | 102 | 41 | 6 | 55 | 45 | 249 | 30 | 121 | 293 | 10 | 69–94 at 70% | bow | no |  |
| Werewolf | 9 | 226 | 111 | 20 | 7 | 58 | 47 | 278 | 30 | 132 | 321 | 11 | 80–108 at 70% | melee | no |  |
| Orc Fighter | 10 | 257 | 120 | 22 | 8 | 61 | 49 | 278 | 30 | 121 | 363 | 12 | 98–132 at 70% | melee | yes |  |
| Werewolf Hunter | 10 | 257 | 120 | 25 | 8 | 55 | 49 | 278 | 30 | 132 | 363 | 12 | 98–132 at 70% | melee | yes |  |
| Orc Lieutenant | 11 | 292 | 129 | 23 | 9 | 70 | 52 | 278 | 30 | 121 | 391 | 15 | 109–147 at 70% | melee | no |  |
| Werewolf Chieftain | 12 | 315 | 138 | 30 | 10 | 60 | 54 | 278 | 30 | 132 | 436 | 16 | 114–157 at 70% | melee | yes |  |
| Orc Fighter Leader | 12 | 315 | 138 | 30 | 10 | 60 | 54 | 278 | 30 | 121 | 447 | 17 | 117–161 at 70% | melee | yes |  |
| Stone Golem | 13 | 339 | 147 | 30 | 11 | 70 | 56 | 278 | 30 | 25 | 654 | 26 | 127–180 at 70% | melee | no | NPC Windstrike - Slow 1 |
| Crasher | 14 | 364 | 156 | 30 | 12 | 80 | 59 | 278 | 30 | 25 | 705 | 27 | 128–189 at 70% | melee | no | NPC Windstrike - Slow 1 |
| Talon Spider | 16 | 417 | 174 | 44 | 15 | 72 | 64 | 278 | 30 | 143 | 570 | 23 | 118–183 at 70% | melee | no |  |
| Blade Spider | 17 | 446 | 184 | 48 | 17 | 75 | 67 | 278 | 30 | 143 | 618 | 26 | 122–197 at 70% | melee | yes |  |
| Young Red Keltir | 1 | 62 | 44 | 9 | 3 | 39 | 32 | 278 | 30 | 121 | 35 | 2 | 8–12 at 70% | melee | no |  |
| Red Keltir | 2 | 75 | 52 | 10 | 3 | 42 | 34 | 278 | 30 | 121 | 70 | 2 | 8–13 at 70% | melee | no |  |
| Elder Red Keltir | 3 | 90 | 60 | 11 | 3 | 44 | 35 | 278 | 30 | 121 | 105 | 2 | 13–20 at 70% | melee | no |  |
| Gray Wolf | 4 | 107 | 68 | 12 | 4 | 46 | 37 | 278 | 30 | 121 | 141 | 4 | 19–29 at 70% | melee | no |  |
| Goblin Raider | 5 | 126 | 77 | 13 | 4 | 48 | 39 | 278 | 30 | 121 | 178 | 5 | 30–42 at 70% | melee | no |  |
| Kaboo Orc | 6 | 147 | 85 | 15 | 5 | 50 | 41 | 278 | 30 | 121 | 213 | 6 | 41–58 at 70% | melee | no |  |
| Kaboo Orc Grunt | 7 | 171 | 94 | 17 | 6 | 53 | 43 | 278 | 30 | 121 | 249 | 8 | 51–72 at 70% | melee | no |  |
| Green Dryad | 8 | 197 | 102 | 18 | 6 | 55 | 45 | 278 | 30 | 121 | 284 | 10 | 67–91 at 70% | melee | no |  |
| Kaboo Orc Archer | 8 | 197 | 102 | 41 | 6 | 55 | 45 | 249 | 30 | 121 | 293 | 10 | 69–94 at 70% | bow | no |  |
| Spore Fungus | 9 | 226 | 111 | 22 | 7 | 53 | 47 | 278 | 30 | 121 | 321 | 11 | 80–108 at 70% | melee | no |  |
| Kaboo Orc Fighter | 10 | 257 | 120 | 20 | 8 | 67 | 49 | 278 | 30 | 121 | 363 | 12 | 98–132 at 70% | melee | yes |  |
| Baraq Orc Fighter | 10 | 257 | 120 | 25 | 8 | 55 | 49 | 278 | 30 | 121 | 302 | 10 | 81–110 at 70% | melee | yes |  |
| Baraq Orc Warrior Leader | 11 | 292 | 129 | 27 | 9 | 58 | 52 | 278 | 30 | 121 | 326 | 12 | 91–122 at 70% | melee | no |  |
| Dungeon Skeleton | 12 | 315 | 138 | 26 | 10 | 60 | 54 | 317 | 30 | 154 | 363 | 13 | 95–131 at 70% | melee | yes |  |
| Dungeon Skeleton Archer | 13 | 339 | 147 | 61 | 11 | 77 | 56 | 249 | 30 | 154 | 397 | 16 | 97–137 at 70% | bow | no |  |
| Dread Soldier | 14 | 364 | 156 | 32 | 12 | 66 | 59 | 317 | 30 | 154 | 424 | 16 | 97–143 at 70% | melee | yes |  |
| Mist Terror | 15 | 390 | 165 | 40 | 14 | 69 | 62 | 278 | 30 | 110 | 454 | 19 | 99–150 at 70% | melee | yes |  |
| Dark Terror | 16 | 417 | 174 | 44 | 15 | 72 | 64 | 278 | 30 | 110 | 533 | 22 | 110–171 at 70% | melee | yes |  |
| Shade Horror | 17 | 446 | 184 | 48 | 17 | 75 | 67 | 278 | 30 | 110 | 504 | 21 | 100–161 at 70% | melee | no |  |
| Sukar Wererat | 18 | 476 | 193 | 46 | 19 | 79 | 70 | 317 | 30 | 132 | 533 | 23 | 101–167 at 70% | melee | no |  |
| Sukar Wererat Leader | 19 | 508 | 203 | 42 | 21 | 99 | 73 | 317 | 30 | 132 | 576 | 26 | 104–177 at 70% | melee | yes |  |
| Dre Vanul Tracker | 20 | 541 | 213 | 63 | 23 | 86 | 76 | 278 | 30 | 88 | 605 | 27 | 106–184 at 70% | melee | yes |  |
| Young Brown Keltir | 1 | 62 | 44 | 9 | 3 | 39 | 32 | 278 | 30 | 121 | 35 | 2 | 8–12 at 70% | melee | no |  |
| Brown Keltir | 2 | 75 | 52 | 10 | 3 | 42 | 34 | 278 | 30 | 121 | 70 | 2 | 8–13 at 70% | melee | no |  |
| Elder Brown Keltir | 3 | 90 | 60 | 11 | 3 | 44 | 35 | 278 | 30 | 121 | 105 | 2 | 13–20 at 70% | melee | no |  |
| Ashen Wolf | 4 | 107 | 68 | 12 | 4 | 46 | 37 | 278 | 30 | 121 | 141 | 4 | 19–29 at 70% | melee | no |  |
| Goblin | 5 | 126 | 77 | 13 | 4 | 48 | 39 | 278 | 30 | 121 | 178 | 5 | 30–42 at 70% | melee | no |  |
| Imp | 6 | 147 | 85 | 15 | 5 | 50 | 41 | 278 | 30 | 88 | 213 | 6 | 41–58 at 70% | melee | no |  |
| Imp Elder | 7 | 171 | 94 | 18 | 6 | 48 | 43 | 278 | 30 | 88 | 249 | 8 | 51–72 at 70% | melee | no |  |
| Balor Orc Archer | 8 | 197 | 102 | 41 | 6 | 55 | 45 | 249 | 30 | 121 | 293 | 10 | 69–94 at 70% | bow | no |  |
| Goblin Lookout | 8 | 197 | 102 | 16 | 6 | 55 | 45 | 317 | 30 | 121 | 284 | 10 | 67–91 at 70% | melee | no |  |
| Green Fungus | 9 | 226 | 111 | 22 | 7 | 53 | 47 | 278 | 30 | 121 | 321 | 11 | 80–108 at 70% | melee | no |  |
| Balor Orc Fighter | 10 | 257 | 120 | 25 | 8 | 55 | 49 | 278 | 30 | 121 | 363 | 12 | 98–132 at 70% | melee | yes |  |
| Goblin Thief | 10 | 257 | 120 | 20 | 8 | 61 | 49 | 317 | 30 | 121 | 356 | 12 | 96–130 at 70% | melee | no |  |
| Vaiss Orc | 10 | 257 | 120 | 22 | 8 | 61 | 49 | 278 | 30 | 121 | 296 | 10 | 80–108 at 70% | melee | no |  |
| Balor Orc Lieutenant | 11 | 292 | 129 | 27 | 9 | 58 | 52 | 278 | 30 | 121 | 391 | 15 | 109–147 at 70% | melee | no |  |
| Vaiss Orc Warrior Leader | 11 | 292 | 129 | 27 | 9 | 58 | 52 | 278 | 30 | 121 | 326 | 12 | 91–122 at 70% | melee | no |  |
| Balor Orc Fighter Leader | 12 | 315 | 138 | 30 | 10 | 60 | 54 | 278 | 30 | 121 | 436 | 16 | 114–157 at 70% | melee | yes |  |
| Blood Fungus | 12 | 315 | 138 | 30 | 10 | 60 | 54 | 278 | 30 | 121 | 427 | 16 | 112–154 at 70% | melee | no |  |
| Skeleton Hunter | 12 | 315 | 138 | 26 | 10 | 60 | 54 | 317 | 30 | 154 | 363 | 13 | 95–131 at 70% | melee | yes |  |
| Doom Soldier | 14 | 364 | 156 | 32 | 12 | 66 | 59 | 317 | 30 | 154 | 424 | 16 | 97–143 at 70% | melee | yes |  |
| Cave Spider | 15 | 390 | 165 | 40 | 14 | 69 | 62 | 278 | 30 | 143 | 445 | 18 | 97–147 at 70% | melee | no |  |
| Cave Fang Spider | 16 | 417 | 174 | 44 | 15 | 72 | 64 | 278 | 30 | 143 | 485 | 20 | 100–156 at 70% | melee | yes |  |
| Omen Beast | 17 | 446 | 184 | 48 | 17 | 75 | 67 | 278 | 30 | 132 | 504 | 21 | 100–161 at 70% | melee | no |  |
| Tainted Zombie | 18 | 476 | 193 | 44 | 19 | 95 | 70 | 278 | 30 | 16 | 754 | 33 | 114–187 at 70% | melee | no |  |
| Stink Zombie | 19 | 508 | 203 | 48 | 21 | 99 | 73 | 278 | 30 | 16 | 799 | 36 | 115–195 at 70% | melee | no | NPC HP Drain - Slow 1 |
| Lesser Succubus | 20 | 541 | 213 | 57 | 23 | 94 | 76 | 278 | 30 | 110 | 605 | 27 | 106–184 at 70% | melee | yes |  |
| Lesser Succubus Turen | 21 | 575 | 227 | 69 | 25 | 89 | 80 | 278 | 30 | 110 | 649 | 30 | 110–197 at 70% | melee | yes | NPC HP Drain - Magic 2, NPC Aura Burn - Magic 2 |
| Lesser Succubus Tilfo | 22 | 611 | 242 | 75 | 28 | 93 | 83 | 278 | 30 | 110 | 698 | 33 | 116–209 at 70% | melee | yes |  |
| Young Prairie Keltir | 1 | 62 | 44 | 9 | 3 | 39 | 32 | 278 | 30 | 121 | 35 | 2 | 8–12 at 70% | melee | no |  |
| Prairie Keltir | 2 | 75 | 52 | 10 | 3 | 42 | 34 | 278 | 30 | 121 | 70 | 2 | 8–13 at 70% | melee | no |  |
| Elder Prairie Keltir | 3 | 90 | 60 | 11 | 3 | 44 | 35 | 278 | 30 | 121 | 105 | 2 | 13–20 at 70% | melee | no |  |
| Kasha Wolf | 4 | 107 | 68 | 12 | 4 | 46 | 37 | 278 | 30 | 121 | 141 | 4 | 19–29 at 70% | melee | no |  |
| Goblin Grave Robber | 5 | 126 | 77 | 13 | 4 | 48 | 39 | 278 | 30 | 121 | 178 | 5 | 30–42 at 70% | melee | no |  |
| Rakeclaw Imp | 6 | 147 | 85 | 16 | 5 | 46 | 41 | 278 | 30 | 88 | 213 | 6 | 41–58 at 70% | melee | no |  |
| Kasha Timber Wolf | 6 | 147 | 85 | 15 | 5 | 50 | 41 | 278 | 30 | 121 | 211 | 6 | 41–58 at 70% | melee | no |  |
| Rakeclaw Imp Hunter | 7 | 171 | 94 | 18 | 6 | 48 | 43 | 278 | 30 | 88 | 249 | 8 | 51–72 at 70% | melee | no |  |
| Mountain Fungus | 8 | 197 | 102 | 20 | 6 | 50 | 45 | 278 | 30 | 121 | 284 | 10 | 67–91 at 70% | melee | no |  |
| Maraku Werewolf | 9 | 226 | 111 | 22 | 7 | 53 | 47 | 278 | 30 | 132 | 321 | 11 | 80–108 at 70% | melee | no |  |
| Evil Eye | 10 | 257 | 120 | 20 | 8 | 67 | 49 | 278 | 30 | 147 | 356 | 12 | 96–130 at 70% | melee | no | NPC Windstrike - Magic 1, NPC Aura Burn - Magic 1 |
| Evil Eye Watcher | 10 | 257 | 120 | 20 | 8 | 67 | 49 | 278 | 30 | 147 | 296 | 10 | 80–108 at 70% | melee | no | NPC HP Drain - Magic 1, NPC Aura Burn - Magic 1 |
| Darkwing Bat | 11 | 292 | 129 | 27 | 9 | 58 | 52 | 278 | 30 | 88 | 391 | 15 | 109–147 at 70% | melee | no |  |
| Grizzly | 12 | 315 | 138 | 27 | 10 | 66 | 54 | 278 | 30 | 121 | 436 | 16 | 114–157 at 70% | melee | yes |  |
| Goblin Tomb Raider Leader | 12 | 315 | 138 | 24 | 10 | 66 | 54 | 317 | 30 | 121 | 427 | 16 | 112–154 at 70% | melee | no |  |
| Slave Skeleton | 12 | 315 | 138 | 26 | 10 | 60 | 54 | 317 | 30 | 154 | 363 | 13 | 95–131 at 70% | melee | yes |  |
| Greystone Golem | 13 | 339 | 147 | 27 | 11 | 77 | 56 | 278 | 30 | 25 | 654 | 26 | 127–180 at 70% | melee | no | NPC Prominence - Slow 1 |
| Grave Keeper | 13 | 339 | 147 | 27 | 11 | 77 | 56 | 278 | 30 | 25 | 545 | 21 | 106–150 at 70% | melee | no | NPC Windstrike - Slow 1 |
| Evil Eye Patroller | 14 | 364 | 156 | 30 | 12 | 80 | 59 | 278 | 30 | 147 | 498 | 19 | 114–168 at 70% | melee | no | NPC Windstrike - Magic 1, NPC Aura Burn - Magic 1 |
| Crypt Horror | 15 | 390 | 165 | 40 | 14 | 69 | 62 | 278 | 30 | 110 | 454 | 19 | 99–150 at 70% | melee | yes |  |
| Kuruka Ratman | 16 | 417 | 174 | 32 | 15 | 87 | 64 | 317 | 30 | 132 | 475 | 19 | 98–153 at 70% | melee | no |  |
| Kuruka Ratman Hunter | 17 | 446 | 184 | 40 | 17 | 91 | 67 | 278 | 30 | 132 | 504 | 21 | 100–161 at 70% | melee | no |  |
| Skeleton Longbowman | 19 | 508 | 203 | 129 | 21 | 82 | 73 | 249 | 30 | 154 | 587 | 26 | 106–181 at 70% | bow | yes |  |
| Undead Slave | 19 | 508 | 203 | 58 | 21 | 82 | 73 | 278 | 30 | 16 | 799 | 36 | 115–195 at 70% | melee | no | NPC Windstrike - Slow 1 |
| Ghost | 20 | 541 | 213 | 63 | 23 | 86 | 76 | 278 | 30 | 154 | 599 | 27 | 105–183 at 70% | melee | yes |  |
| Ghost Guardian | 21 | 575 | 227 | 63 | 25 | 98 | 80 | 278 | 30 | 154 | 643 | 30 | 109–195 at 70% | melee | yes |  |

Example: a Young Keltir (DEX 30, level 1) has Accuracy and Evasion √30 × 6 + 1 = **34** and a
**4.4%** Critical.

## 19. Skills

Every set has a first skill from its own tree and starts knowing it: a Mystic its first spell, Wind
Strike or the Orc's Chill Flame, because a Mystic's STR makes a poor weapon of whatever it holds,
and a Fighter the skill of the weapon it starts with, each race's its own. The trainer (§25) teaches
the rest before the class change, each set its own. A Mystic can learn one more at level 1 (Self
Heal, or the Orc's Soul Cry), and a Fighter the first level of its other weapon skills, if it has
any. Each costs MP and then rests for its reuse, but for its masteries, passives that are never
cast and add to a stat for as long as they are known: Armor Mastery for a Fighter, Robe Mastery for
a Mystic, and Weapon Mastery and Anti Magic for both, each learned or not as the player sees fit.

| Set | First skill | Also at level 1 | Then |
|---|---|---|---|
| Human Fighter | Power Strike | Mortal Blow, Power Shot | Armor Mastery, Weapon Mastery, Anti Magic |
| Elven Fighter | Power Shot | | Defense Aura, Elemental Heal, Armor Mastery, Weapon Mastery, Anti Magic |
| Dark Fighter | Mortal Blow | | Attack Aura, Drain Health, Armor Mastery, Weapon Mastery, Anti Magic |
| Orc Fighter | Iron Punch | Power Strike | Relax, Armor Mastery, Weapon Mastery, Anti Magic |
| Human Mystic | Wind Strike | Self Heal | Ice Bolt, Robe Mastery, Weapon Mastery, Anti Magic |
| Elven Mystic | Wind Strike | Self Heal | Ice Bolt, Heal, Robe Mastery, Weapon Mastery, Anti Magic |
| Dark Mystic | Wind Strike | Self Heal | Vampiric Touch, Curse: Poison, Shield, Wind Shackle, Robe Mastery, Weapon Mastery, Anti Magic |
| Orc Mystic | Chill Flame | Soul Cry | Life Drain, Soul Shield, Robe Mastery, Weapon Mastery, Anti Magic |

Each at level 1 (§25 has the later levels):

| Skill | Kind | Power | MP | Reuse | Cast |
|---|---|---|---|---|---|
| Power Strike | physical | 25 | 10 | 13,000 | |
| Power Shot | physical | 65 | 19 | 25,000 | |
| Mortal Blow | blow | 73 | 9 | 11,000 | |
| Iron Punch | physical | 29 | 11 | 15,000 | |
| Wind Strike | magic | 12 | 9 | 6,000 | 4,000 |
| Ice Bolt | magic | 9 | 10 | 8,000 | 3,300 |
| Vampiric Touch | drain | 21 | 28 | 12,000 | 4,000 |
| Chill Flame | burn | 20 | 15 | 6,000 | 4,000 |
| Drain Health | drain | 22 | 13 | 15,000 | 3,000 |
| Life Drain | drain | 15 | 27 | 6,000 | 4,000 |
| Self Heal | heal | 42 | 9 | 10,000 | 5,000 |
| Heal | heal | 67 | 14 | 10,000 | 5,000 |
| Elemental Heal | heal | 80 | 45 | 10,000 | 5,000 |
| Defense Aura | aura | | 5 | 6,000 | 4,000 |
| Attack Aura | aura | | 7 | 6,000 | 4,000 |
| Shield | aura | | 10 | 6,000 | 4,000 |
| Soul Shield | aura | | 10 | 5,000 | 2,500 |
| Curse: Poison | poison | 24 | 10 | 12,000 | 4,000 |
| Wind Shackle | shackle | | 3 | 8,000 | 1,500 |
| Soul Cry | toggle | 4.5 | 2 | | |
| Relax | rest | 5 | 3 | | |
| Armor Mastery | passive | | | | |
| Robe Mastery | passive | | | | |
| Weapon Mastery | passive | | | | |
| Anti Magic | passive | | | | |

A spell takes effect as its cast ends, in the round its cast time runs out, though its MP is paid
and its reuse begins as it is begun; a physical skill or a blow takes effect at once. So it is with
a monster's spells. Reuse and cast are in milliseconds. The reuse is × 333 ÷ Atk. Spd. for a
physical skill or a blow and × 333 ÷ Casting Spd. for the rest, and a cast is × 333 ÷ Casting Spd.
A physical skill takes the place of a blow and has no cast of its own. Power Strike, Power Shot,
Mortal Blow and Iron Punch need their weapons (§23); the rest need none.

- **Physical:** 70 × (P. Atk. + power) ÷ P. Def., then the weapon's spread (§13). It never misses and
  never lands a critical.
- **Blow:** the same damage, landing 40% × the DEX bonus of the time, at most 80%, and otherwise
  doing nothing.
- **Magic:** §13's magic damage, which can be a magic critical. A spell never misses.
- **Drain:** magic damage, healing the caster a share of what the target lost: 40% for Vampiric
  Touch, 20% for Drain Health and 80% for Life Drain.
- **Burn:** power HP a second for 15 seconds, which can take the last HP. It is not cast again on a
  target that still burns.
- **Ice Bolt** also slows its target for 120 seconds: a slowed monster swings 30% less and runs 30%
  slower.
- **Heal:** power + √M. Atk. HP back, rounded down and never past the most.
- **Aura:** Defense Aura, Shield and Soul Shield raise P. Def. by 8% and Attack Aura P. Atk. by 8%, for
  2 minutes, in the fight and out of it. Shield and Soul Shield are cast on another in Lineage II,
  and the caster is the one here.
- **Poison:** lands 70% of the time, and then takes power HP every 3 seconds for 30 seconds, never
  the last HP. It is not cast again on a target already poisoned.
- **Shackle:** lands 80% of the time, and then the target swings × 0.83 for 15 seconds.
- **Toggle:** its MP lights it for the fight, adding its power to P. Atk., and it then drains MP every
  3 seconds (Soul Cry 3 at level 1 and 6 at level 2), going out when the MP runs short.
- **Rest:** Relax mends power HP more on every tick of rest (§11), for its MP. Lineage II drains 2
  MP every 2 seconds, which is 3 a tick.
- **Passive:** multiplies a stat by the shares §25's passive table gives the line it is known at,
  then adds its bonuses, as Lineage II does whatever order its data lists them in, after §7 to §10
  and before any aura. A bonus
  that names what is worn holds only while the chest piece worn is of that kind (§23): Robe
  Mastery's P. Def. in a robe, Armor Mastery's Evasion in light armour. Weapon Mastery is a Fighter's
  P. Atk. and a Mystic's M. Atk. (and its P. Atk.), each its own lines, as in Lineage II, whose slower
  casting for a Mystic with a bow or a polearm never applies, since no Mystic is sold either.

Monsters cast these:

| Spell | Kind | Power | MP | Reuse | Cast | Range |
|---|---|---|---|---|---|---|
| NPC Windstrike - Magic 1 | magic | 18 | 7 | 3,000 | 4,000 | 600 |
| NPC HP Drain - Magic 1 | drain | 18 | 9 | 3,000 | 4,000 | 600 |
| NPC HP Drain - Magic 2 | drain | 26 | 14 | 3,000 | 4,000 | 600 |
| NPC Aura Burn - Magic 1 | magic | 5 | 3 | 1,000 | 1,500 | 150 |
| NPC Aura Burn - Magic 2 | magic | 7 | 3 | 1,000 | 1,500 | 150 |
| NPC Windstrike - Slow 1 | magic | 5 | 13 | 8,000 | 2,000 | 1,000 |
| NPC Windstrike - Slow 2 | magic | 8 | 20 | 8,000 | 2,000 | 1,000 |
| NPC HP Drain - Slow 1 | drain | 5 | 17 | 8,000 | 2,000 | 1,000 |
| NPC Prominence - Slow 1 | magic | 5 | 13 | 8,000 | 2,000 | 1,000 |

A monster's drain heals it 20% of what the character lost.

Example: a level 1 Human Fighter with its Squire's Sword (P. Atk. 6.48) strikes a Young Keltir (P. Def.
39) with Power Strike for 70 × (6.48 + 25) ÷ 39 = **56.5** before the ±10%, where a blow does
**11.6**. A Dark Fighter's DEX 34 lands Mortal Blow 40 × 1.14 = **45.6%** of the time. The Human
Fighter's Atk. Spd. 416 rests Power Strike 13,000 × 333 ÷ 416 = **10,406** milliseconds. A Mystic
with 20 M. Atk. mends 42 + √20 = 46.47, so **46** HP, with Self Heal.

## 20. The hunt

One click, one fight. Each village's ground (§17) is hunted from the village, a monster at a time.
It is fought on one line between the two, at a distance in Lineage II's units, and each reaches
this far (a monster's spells as far as §19 gives):

| Reach | Distance |
|---|---|
| A blow, or a physical skill | 40 |
| A bow's shot | 500 |
| A character's spell | 600 |
| An aggressive monster noticing a character | 500 |

- **Who you meet:** one of the ground's monsters from 3 levels below the character up to its own
  level, each as likely as the next, or one of the nearest if none is. Nothing on a village's ground
  is ever stronger than the character who meets it there.
- **A round** is 1⅔ seconds, one blow at 300 Atk. Spd. (Lineage II's 500,000 ÷ Atk. Spd.
  milliseconds). The character acts, then the monster if it still stands, and a skill's reuse runs
  down by 1⅔ seconds each round.
- **The opening:** a Mystic pulls the monster from a spell's reach if it can pay for one; a Fighter,
  or a Mystic that cannot, from its weapon's, its bow's or else its blows'. An aggressive monster
  (§18) is not pulled: it notices the character from 500 and comes at it, acting first in the first
  round. Any other stands where it is until the character's first blow, shot, spell or curse lands
  on it or misses, so a bow's first draw and a spell's first cast are free. A monster runs at the
  character, its run speed (§18) a second and 30% slower while slowed
  (§19), until a spell it has ready, its bow or its blows reach, and a round it runs is a round it
  does nothing else. A character whose blows cannot reach waits for a monster that is coming, and
  runs at one that is not, at its own run speed (§10). Once both are within reach, neither moves
  again.
- **The character** uses the first of these it knows that is ready and paid for (§19):
  1. a toggle not lit, which a Mystic lights only once its blows reach;
  2. the strongest spell (magic, drain or burn), but a burn not on a monster still burning, and a
     drain that returns at least half of what it deals (Life Drain) only below 85% of its HP, as
     the heal it mostly is;
  3. below the share of its HP its orders give, the strongest heal, so a heal fills the time its
     spells rest and never stops it attacking;
  4. while the monster has more than half its HP, a poison it does not carry, then a shackle.

  A spell takes its cast time (§19), × 333 ÷ Casting Spd., in which the character does nothing
  else. With none of these ready, it swings its blows (§10), and a physical skill or a blow that is
  ready takes the place of one.
- **The monster** swings its blows the same way, at its own Atk. Spd., and a monster with a bow
  draws and reloads as a character's bow does (§10). A monster with spells casts the strongest that
  is ready instead, and does nothing else for its cast time. Its reuse and cast time are not
  scaled. One with a short-range spell, reaching 150 or less, casts it while the character is
  within 100 and only its other spells beyond, so an Evil Eye burns a character beside it with
  Aura Burn and drains or strikes one at a distance.
- **Blows** hit and do damage as §13 says. Skills and spells do what §19 says.
- **It ends** when either reaches 0 HP. After 1,000 rounds the monster wanders off and pays nothing.
- **Before the pull**, the character first raises every aura it knows that is not up and that it
  can pay for, each cast to its end, so no round of the fight goes on one. Then, since it rests
  nothing on the ground (§11), it heals while its HP is below the share its orders give: the strongest heal it can pay for, never past the most,
  waiting out the reuse and cast, until it is not or it cannot pay for one. A heal cast before the
  pull is still resting when the fight begins. It does not heal once the monster is down, so MP is
  never spent on a walk back to rest.
- **Orders** are the player's, for a character that knows a heal: the share of HP to heal below
  before the pull and in the fight, never or below 30%, 50% or 70%; below 70% before the pull and
  never in the fight to begin with, since a character topped up before each pull outlives one that
  is not, and a heal cast while the monster strikes mends less than the strikes take before it
  lands.
- **A skill left unused:** the player may also order the character to leave any skill it knows
  unused, but a heal, whose orders are its shares, and Relax, and to use it again. It then fights as
  if it did not know it: a Mystic with no spell left pulls with its weapon. Every skill is used to
  begin with.
- **The reward** for a kill is the monster's EXP and SP (§12) and its Adena, each × its server rate
  (§22). A character more than 5 levels above the monster earns × (5 ÷ 6) for each level past the
  fifth, rounded down.
- **In combat:** going out to the ground meets nothing until the player looks for a fight, but the
  character is in combat from the moment it arrives, fighting or not, and does not rest (§11) for as
  long as it stays there. Leaving the ground, by retreating to town or any other way, it is in combat
  for 5 seconds more, and then rests.
- **What is left** of HP and MP stays, until the character is back in town to rest.

Example: at EXP ×5, a level 12 character who kills a Young Keltir (level 1, 35 EXP) is 11 levels
above it, 6 past the fifth, and earns 35 × 5 × (5 ÷ 6)⁶ = 58.6, so **58** EXP. A level 6 character
earns all of it, **175**.

## 21. Death

At 0 HP the run is over. The character is written as fallen, with what killed it and where, and
nothing of it carries over: the browser goes back to game start for the next one. It keeps its place
on the Monument of Heroes, which ranks every run by EXP and so by level, then EXP, then Adena.

Example: a level 9 run with 40,000 EXP that dies stands above every level 8 run, and above a level 9
run with 39,999 EXP.

## 22. Server rates

Every Lineage II server ran at rates, multiplying what monsters pay. Retail ran at ×1, and so does
this game unless its operator sets others (`EXP_RATE`, `SP_RATE` and `ADENA_RATE`). The game is
balanced at the private rates, those private servers such as the ones on aCis ran, which every env
file it ships sets:

| Rate | Retail | Private |
|---|---|---|
| EXP | 1 | 5 |
| SP | 1 | 5 |
| Adena | 1 | 20 |

Adena runs four times faster than EXP because the village shops price their gear for a game where
most Adena came from quests and from selling what monsters dropped, and the hunt has neither. At the
private rates, a seeded run of every set up its village's ladder takes about 310 to 390 kills from
level 1 to 20, and holds about 55,000 Adena at level 11 and 250,000 at level 16, where a Gladius
costs 62,215 and a Long Sword 156,400.

Example: a Young Keltir carrying 10 Adena pays **10** at retail's rate and **200** at ×20.

## 23. Gear

A character carries up to 15 items, what it wears among them and a potion's stack counting as one
(§26), and wears at most one in each of five slots: weapon, shield, chest, legs and necklace. A
two-handed weapon (a bow, fists, a two-handed sword or staff) takes the shield's hand, so putting
one on takes the shield off, and the other way round. Nothing is weighed.

Every set starts with its kit, the wearable part equipped. A fighter's kit holds a weapon for each
skill its trainer teaches that needs one (§25), the one its first skill needs in hand, and no shop
sells anything in a kit:

| Kit | Equipped | Carried |
|---|---|---|
| Human Fighter | Squire's Sword, Squire's Shirt, Squire's Pants | Squire's Dagger, Squire's Bow |
| Elven Fighter | Squire's Bow, Squire's Shirt, Squire's Pants | |
| Dark Fighter | Squire's Dagger, Squire's Shirt, Squire's Pants | |
| Orc Fighter | Squire's Gloves, Squire's Shirt, Squire's Pants | Squire's Sword |
| Human Mystic | Apprentice's Wand, Apprentice's Tunic, Apprentice's Stockings | |
| Elven Mystic | Apprentice's Wand, Apprentice's Tunic, Apprentice's Stockings | |
| Dark Mystic | Apprentice's Wand, Apprentice's Tunic, Apprentice's Stockings | |
| Orc Mystic | Apprentice's Wand, Apprentice's Tunic, Apprentice's Stockings | |

- **Five kinds of weapon:** a sword, one-handed or two; a dagger; a bow; fists; and a staff, which
  a mystic's wand, book, horn and relic are too, one-handed.
- **A first skill (§19) needs its weapon:** Power Strike a sword, in either hand, Power Shot a bow,
  Mortal Blow a dagger, Iron Punch fists. Without it the skill is never used and costs nothing, and
  the character only swings. Spells need none.
- **A shield** catches a monster's blow at its block rate × the DEX bonus, as a percentage, three
  times as often against an arrow and three times as often against a critical. One roll decides:
  five blows in a hundred are caught perfectly, whatever the shield, and take only 1, and the rest
  of the catches add the shield's defence to P. Def. for that blow. Spells pass a shield by. Every
  shield blocks at 20 and costs 8 Evasion (§8) while worn, so a better shield catches no more often,
  only harder, and blows land more often behind any of them.
- **A robe's MP** is added to Max MP (§6).

Example: a Human Fighter (DEX 30) behind a Small Shield (defence 56, block 20) catches 20 × 1.10 =
**22%** of the blows aimed at it, 5% of them perfectly, and 22 × 3 = **66%** of the arrows. A Human Mystic's starting robes add 19 + 10 = **29** Max MP.

## 24. Village shops

Every starting village sells the items marked village below, and Orc Village those marked
orc-village too, each at its canon price below × as many of its slot as it stands for (§7), rounded,
so a chest, legs or necklace costs what it is worth as it counts what it is worth: a light piece by a
Fighter's shares, a robe by a Mystic's, a necklace × 41 ÷ 13, anything else its price. A shop buys
back anything it sells for half what it costs, rounded down. A starting kit is worth nothing to a
shop and is never bought.

Each village keeps four traders: one for weapons, one for armour who sells the shields too, and a
jeweller and a grocer who keep the Magic Trader together, its jewellery and its potions. Any of them
buys back:

| Village | Weapon Trader | Armour Trader | Jeweller | Grocer |
|---|---|---|---|---|
| Talking Island Village | Lector | Jackson | Silvia | Katerina |
| Elven Village | Unoren | Ariel | Creamees | Herbiel |
| Dark Elf Village | Iria | Payne | Minaless | Vollodos |
| Orc Village | Jakal | Kunai | Uska | Papuma |

A trader shows a set only what its path uses, and sells it nothing else: a Fighter the weapons its
own skills need (§23) and light armour, a Mystic staves and robes, and both every shield, necklace
and potion.

| Item | Kind | Slot | Hands | Type | P. Atk. | M. Atk. | Atk. Spd. | Critical | Accuracy | Spread | P. Def. | M. Def. | Shield | Block | Evasion | MP | Price | Sold |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Apprentice's Wand | weapon | weapon | 1 | staff | 5 | 7 | 379 | 4 | 4 | 20 |  |  |  |  |  |  | 138 | starting |
| Squire's Bow | weapon | weapon | 2 | bow | 14 | 5 | 293 | 12 | -3 | 5 |  |  |  |  |  |  | 138 | starting |
| Short Bow | weapon | weapon | 2 | bow | 16 | 6 | 293 | 12 | -3 | 5 |  |  |  |  |  |  | 768 | village |
| Bow | weapon | weapon | 2 | bow | 23 | 9 | 293 | 12 | -3 | 5 |  |  |  |  |  |  | 12500 | village |
| Hunting Bow | weapon | weapon | 2 | bow | 34 | 12 | 293 | 12 | -3 | 5 |  |  |  |  |  |  | 54100 | village |
| Forest Bow | weapon | weapon | 2 | bow | 49 | 17 | 293 | 12 | -3 | 5 |  |  |  |  |  |  | 136000 | village |
| Squire's Dagger | weapon | weapon | 1 | dagger | 5 | 5 | 433 | 12 | -3 | 5 |  |  |  |  |  |  | 138 | starting |
| Bone Dagger | weapon | weapon | 1 | dagger | 7 | 6 | 433 | 12 | -3 | 5 |  |  |  |  |  |  | 768 | village |
| Knife | weapon | weapon | 1 | dagger | 10 | 9 | 433 | 12 | -3 | 5 |  |  |  |  |  |  | 12500 | village |
| Dirk | weapon | weapon | 1 | dagger | 15 | 12 | 433 | 12 | -3 | 5 |  |  |  |  |  |  | 54100 | village |
| Throwing Knife | weapon | weapon | 1 | dagger | 21 | 17 | 433 | 12 | -3 | 5 |  |  |  |  |  |  | 136000 | village |
| Squire's Gloves | weapon | weapon | 2 | fists | 7 | 5 | 325 | 4 | 4 | 5 |  |  |  |  |  |  | 138 | starting |
| Spiked Gloves | weapon | weapon | 2 | fists | 10 | 6 | 325 | 4 | 4 | 5 |  |  |  |  |  |  | 768 | orc-village |
| Iron Gloves | weapon | weapon | 2 | fists | 13 | 9 | 325 | 4 | 4 | 5 |  |  |  |  |  |  | 12500 | orc-village |
| Fox Claw Gloves | weapon | weapon | 2 | fists | 21 | 12 | 325 | 4 | 4 | 5 |  |  |  |  |  |  | 54100 | orc-village |
| Cestus | weapon | weapon | 2 | fists | 29 | 17 | 325 | 4 | 4 | 5 |  |  |  |  |  |  | 136000 | orc-village |
| Buffalo's Horn | weapon | weapon | 1 | staff | 6 | 8 | 379 | 8 | 0 | 10 |  |  |  |  |  |  | 768 | village |
| Scholar's Tome | weapon | weapon | 1 | staff | 9 | 12 | 379 | 8 | 0 | 10 |  |  |  |  |  |  | 12500 | village |
| Relic of The Saints | weapon | weapon | 1 | staff | 19 | 22 | 379 | 8 | 0 | 10 |  |  |  |  |  |  | 136000 | village |
| Squire's Sword | weapon | weapon | 1 | sword | 6 | 5 | 379 | 8 | 0 | 10 |  |  |  |  |  |  | 138 | starting |
| Short Sword | weapon | weapon | 1 | sword | 8 | 6 | 379 | 8 | 0 | 10 |  |  |  |  |  |  | 768 | village |
| Broadsword | weapon | weapon | 1 | sword | 11 | 9 | 379 | 8 | 0 | 10 |  |  |  |  |  |  | 12500 | village |
| Gladius | weapon | weapon | 1 | sword | 17 | 12 | 379 | 8 | 0 | 10 |  |  |  |  |  |  | 54100 | village |
| Long Sword | weapon | weapon | 1 | sword | 24 | 17 | 379 | 8 | 0 | 10 |  |  |  |  |  |  | 136000 | village |
| Willow Staff | weapon | weapon | 2 | staff | 11 | 12 | 325 | 4 | 4 | 20 |  |  |  |  |  |  | 12500 | village |
| Cedar Staff | weapon | weapon | 2 | staff | 16 | 16 | 325 | 4 | 4 | 20 |  |  |  |  |  |  | 54100 | village |
| Journeyman's Staff | weapon | weapon | 2 | staff | 23 | 22 | 325 | 4 | 4 | 20 |  |  |  |  |  |  | 136000 | village |
| Brandish | weapon | weapon | 2 | sword | 21 | 12 | 325 | 8 | 0 | 10 |  |  |  |  |  |  | 54100 | village |
| Zweihander | weapon | weapon | 2 | sword | 38 | 21 | 325 | 8 | 0 | 10 |  |  |  |  |  |  | 244000 | village |
| Leather Shield | shield | shield |  |  |  |  |  |  |  |  |  |  | 47 | 20 | -8 |  | 39 | village |
| Small Shield | shield | shield |  |  |  |  |  |  |  |  |  |  | 56 | 20 | -8 |  | 638 | village |
| Buckler | shield | shield |  |  |  |  |  |  |  |  |  |  | 67 | 20 | -8 |  | 2780 | village |
| Round Shield | shield | shield |  |  |  |  |  |  |  |  |  |  | 79 | 20 | -8 |  | 7110 | village |
| Squire's Shirt | armour | chest |  | light |  |  |  |  |  |  | 33 |  |  |  |  |  | 26 | starting |
| Shirt | armour | chest |  | light |  |  |  |  |  |  | 36 |  |  |  |  |  | 147 | village |
| Leather Shirt | armour | chest |  | light |  |  |  |  |  |  | 43 |  |  |  |  |  | 2430 | village |
| Wooden Breastplate | armour | chest |  | light |  |  |  |  |  |  | 47 |  |  |  |  |  | 7960 | village |
| Bone Breastplate | armour | chest |  | light |  |  |  |  |  |  | 50 |  |  |  |  |  | 20300 | village |
| Apprentice's Tunic | armour | chest |  | magic |  |  |  |  |  |  | 17 |  |  |  |  | 19 | 26 | starting |
| Tunic | armour | chest |  | magic |  |  |  |  |  |  | 18 |  |  |  |  | 24 | 147 | village |
| Cotton Tunic | armour | chest |  | magic |  |  |  |  |  |  | 21 |  |  |  |  | 38 | 2430 | village |
| Leather Tunic | armour | chest |  | magic |  |  |  |  |  |  | 25 |  |  |  |  | 52 | 7960 | village |
| Tunic of Devotion | armour | chest |  | magic |  |  |  |  |  |  | 30 |  |  |  |  | 67 | 20300 | village |
| Squire's Pants | armour | legs |  | light |  |  |  |  |  |  | 20 |  |  |  |  |  | 6 | starting |
| Pants | armour | legs |  | light |  |  |  |  |  |  | 22 |  |  |  |  |  | 92 | village |
| Leather Pants | armour | legs |  | light |  |  |  |  |  |  | 27 |  |  |  |  |  | 1520 | village |
| Wooden Gaiters | armour | legs |  | light |  |  |  |  |  |  | 29 |  |  |  |  |  | 4970 | village |
| Bone Gaiters | armour | legs |  | light |  |  |  |  |  |  | 32 |  |  |  |  |  | 12700 | village |
| Apprentice's Stockings | armour | legs |  | magic |  |  |  |  |  |  | 10 |  |  |  |  | 10 | 6 | starting |
| Stockings | armour | legs |  | magic |  |  |  |  |  |  | 11 |  |  |  |  | 15 | 92 | village |
| Cotton Stockings | armour | legs |  | magic |  |  |  |  |  |  | 13 |  |  |  |  | 23 | 1520 | village |
| Leather Stockings | armour | legs |  | magic |  |  |  |  |  |  | 16 |  |  |  |  | 33 | 4970 | village |
| Stockings of Devotion | armour | legs |  | magic |  |  |  |  |  |  | 19 |  |  |  |  | 42 | 12700 | village |
| Necklace of Magic | jewellery | necklace |  |  |  |  |  |  |  |  |  | 15 |  |  |  |  | 66 | village |
| Necklace of Knowledge | jewellery | necklace |  |  |  |  |  |  |  |  |  | 18 |  |  |  |  | 1080 | village |
| Necklace of Anguish | jewellery | necklace |  |  |  |  |  |  |  |  |  | 21 |  |  |  |  | 4680 | village |
| Necklace of Wisdom | jewellery | necklace |  |  |  |  |  |  |  |  |  | 25 |  |  |  |  | 11900 | village |

Example: a Broadsword costs **12,500** and sells back for **6,250**. A Leather Shirt (2,430) costs
2,430 × 51 ÷ 31 = **3,998**, a Leather Tunic (7,960) 7,960 × 35 ÷ 15 = **18,573**, and a Necklace of
Wisdom (11,900) 11,900 × 41 ÷ 13 = **37,531**, which sells back for **18,765**.

## 25. The guild

Each starting village's trainers teach its own race and nobody else, for the SP a character earns
on the hunt (§20). They teach in the village's guild, one per path in Talking Island Village and the
Orc Village and one for both in the Elven and Dark Elf Villages, and only a set's own trainers teach
it:

| Set | Guild | Trainers |
|---|---|---|
| Human Fighter | Warriors Guild | Master Gwinter, Master Minia, Master Pintage |
| Human Mystic | Mystics Guild | Magister Baulro, Magister Harrys, Priest Yohanes, Priest Petron |
| Elven Fighter | Eva's Sanctuary | Master Ellenia, Master Cobendell |
| Elven Mystic | Eva's Sanctuary | Magister Greenis, Magister Esrandell |
| Dark Fighter | Temple of Shilen | Master Trudy, Master Harant |
| Dark Mystic | Temple of Shilen | Magister Vlasty, Magister Harne |
| Orc Fighter | Warriors Guild | Prefect Brukurse, Prefect Karukia |
| Orc Mystic | Mystics Guild | Seer Tanapi, Seer Livina |

A line is learned once the character has reached its level, knows the level before it, and pays
its SP. Each set's list is short: its first skill and the others §19 gives it,
each at every level. Only the first skill's level 1 is taught for nothing, and so is known from the
start; a Mystic's other line at level 1 costs 50, and a Fighter's other weapon skills begin at
level 1 for 50 (60 for the Orc).

A skill grows in steps, not one level at a time: each line is everything the trainer teaches of it
at one character level (5, 10 and 15 for a Fighter, 7 and 14 for a Mystic), so no two lines of one
skill open at the same level. A Fighter's weapon skills keep their first level apart, at level 1.
Every line costs what Lineage II asks for the levels it holds, but for level 1 (above) and two
masteries taught beyond their canon trees: every Mystic learns Robe Mastery at the Orc Mystic's
price, and a Fighter Anti Magic, which Lineage II teaches only Mystics, at levels 5 and 10 for what
its race's Mystic pays.

| Set | Skill | Level | From level | SP |
|---|---|---|---|---|
| Human Fighter | Power Strike | 1 | 1 | 0 |
| Human Fighter | Power Strike | 2 | 5 | 100 |
| Human Fighter | Power Strike | 3 | 10 | 1,110 |
| Human Fighter | Power Strike | 4 | 15 | 3,900 |
| Human Fighter | Mortal Blow | 1 | 1 | 50 |
| Human Fighter | Mortal Blow | 2 | 5 | 100 |
| Human Fighter | Mortal Blow | 3 | 10 | 1,110 |
| Human Fighter | Mortal Blow | 4 | 15 | 3,900 |
| Human Fighter | Power Shot | 1 | 1 | 50 |
| Human Fighter | Power Shot | 2 | 5 | 100 |
| Human Fighter | Power Shot | 3 | 10 | 1,110 |
| Human Fighter | Power Shot | 4 | 15 | 3,900 |
| Human Fighter | Armor Mastery | 1 | 5 | 160 |
| Human Fighter | Armor Mastery | 2 | 10 | 1,100 |
| Human Fighter | Armor Mastery | 3 | 15 | 4,000 |
| Human Fighter | Weapon Mastery | 1 | 5 | 160 |
| Human Fighter | Weapon Mastery | 2 | 10 | 1,100 |
| Human Fighter | Weapon Mastery | 3 | 15 | 4,000 |
| Human Fighter | Anti Magic | 1 | 5 | 480 |
| Human Fighter | Anti Magic | 2 | 10 | 2,200 |
| Elven Fighter | Power Shot | 1 | 1 | 0 |
| Elven Fighter | Power Shot | 2 | 5 | 100 |
| Elven Fighter | Power Shot | 3 | 10 | 930 |
| Elven Fighter | Power Shot | 4 | 15 | 3,300 |
| Elven Fighter | Defense Aura | 1 | 5 | 160 |
| Elven Fighter | Elemental Heal | 1 | 15 | 3,300 |
| Elven Fighter | Armor Mastery | 1 | 5 | 160 |
| Elven Fighter | Armor Mastery | 2 | 10 | 920 |
| Elven Fighter | Armor Mastery | 3 | 15 | 3,400 |
| Elven Fighter | Weapon Mastery | 1 | 5 | 160 |
| Elven Fighter | Weapon Mastery | 2 | 10 | 910 |
| Elven Fighter | Weapon Mastery | 3 | 15 | 3,300 |
| Elven Fighter | Anti Magic | 1 | 5 | 520 |
| Elven Fighter | Anti Magic | 2 | 10 | 2,200 |
| Dark Fighter | Mortal Blow | 1 | 1 | 0 |
| Dark Fighter | Mortal Blow | 2 | 5 | 100 |
| Dark Fighter | Mortal Blow | 3 | 10 | 930 |
| Dark Fighter | Mortal Blow | 4 | 15 | 2,850 |
| Dark Fighter | Attack Aura | 1 | 10 | 910 |
| Dark Fighter | Drain Health | 1 | 15 | 2,800 |
| Dark Fighter | Armor Mastery | 1 | 5 | 160 |
| Dark Fighter | Armor Mastery | 2 | 10 | 920 |
| Dark Fighter | Armor Mastery | 3 | 15 | 2,800 |
| Dark Fighter | Weapon Mastery | 1 | 5 | 160 |
| Dark Fighter | Weapon Mastery | 2 | 10 | 910 |
| Dark Fighter | Weapon Mastery | 3 | 15 | 2,900 |
| Dark Fighter | Anti Magic | 1 | 5 | 480 |
| Dark Fighter | Anti Magic | 2 | 10 | 2,200 |
| Orc Fighter | Iron Punch | 1 | 1 | 0 |
| Orc Fighter | Iron Punch | 2 | 5 | 120 |
| Orc Fighter | Iron Punch | 3 | 10 | 1,380 |
| Orc Fighter | Iron Punch | 4 | 15 | 3,900 |
| Orc Fighter | Power Strike | 1 | 1 | 60 |
| Orc Fighter | Power Strike | 2 | 5 | 120 |
| Orc Fighter | Power Strike | 3 | 10 | 1,380 |
| Orc Fighter | Power Strike | 4 | 15 | 3,900 |
| Orc Fighter | Relax | 1 | 5 | 190 |
| Orc Fighter | Armor Mastery | 1 | 5 | 190 |
| Orc Fighter | Armor Mastery | 2 | 10 | 1,380 |
| Orc Fighter | Armor Mastery | 3 | 15 | 4,000 |
| Orc Fighter | Weapon Mastery | 1 | 5 | 190 |
| Orc Fighter | Weapon Mastery | 2 | 10 | 1,300 |
| Orc Fighter | Weapon Mastery | 3 | 15 | 4,000 |
| Orc Fighter | Anti Magic | 1 | 5 | 520 |
| Orc Fighter | Anti Magic | 2 | 10 | 1,760 |
| Human Mystic | Wind Strike | 1 | 1 | 0 |
| Human Mystic | Wind Strike | 2 | 7 | 480 |
| Human Mystic | Wind Strike | 3 | 14 | 2,200 |
| Human Mystic | Self Heal | 1 | 1 | 50 |
| Human Mystic | Ice Bolt | 1 | 7 | 480 |
| Human Mystic | Ice Bolt | 2 | 14 | 2,200 |
| Human Mystic | Robe Mastery | 1 | 7 | 520 |
| Human Mystic | Robe Mastery | 2 | 14 | 1,760 |
| Human Mystic | Weapon Mastery | 1 | 7 | 470 |
| Human Mystic | Weapon Mastery | 2 | 14 | 2,100 |
| Human Mystic | Anti Magic | 1 | 7 | 480 |
| Human Mystic | Anti Magic | 2 | 14 | 2,200 |
| Elven Mystic | Wind Strike | 1 | 1 | 0 |
| Elven Mystic | Wind Strike | 2 | 7 | 520 |
| Elven Mystic | Wind Strike | 3 | 14 | 2,200 |
| Elven Mystic | Self Heal | 1 | 1 | 50 |
| Elven Mystic | Ice Bolt | 1 | 7 | 520 |
| Elven Mystic | Ice Bolt | 2 | 14 | 2,200 |
| Elven Mystic | Heal | 1 | 7 | 510 |
| Elven Mystic | Heal | 2 | 14 | 2,100 |
| Elven Mystic | Robe Mastery | 1 | 7 | 520 |
| Elven Mystic | Robe Mastery | 2 | 14 | 1,760 |
| Elven Mystic | Weapon Mastery | 1 | 7 | 520 |
| Elven Mystic | Weapon Mastery | 2 | 14 | 2,100 |
| Elven Mystic | Anti Magic | 1 | 7 | 520 |
| Elven Mystic | Anti Magic | 2 | 14 | 2,200 |
| Dark Mystic | Wind Strike | 1 | 1 | 0 |
| Dark Mystic | Wind Strike | 2 | 7 | 480 |
| Dark Mystic | Wind Strike | 3 | 14 | 2,200 |
| Dark Mystic | Self Heal | 1 | 1 | 50 |
| Dark Mystic | Vampiric Touch | 1 | 14 | 2,200 |
| Dark Mystic | Curse: Poison | 1 | 7 | 470 |
| Dark Mystic | Shield | 1 | 7 | 470 |
| Dark Mystic | Wind Shackle | 1 | 14 | 2,100 |
| Dark Mystic | Robe Mastery | 1 | 7 | 520 |
| Dark Mystic | Robe Mastery | 2 | 14 | 1,760 |
| Dark Mystic | Weapon Mastery | 1 | 7 | 470 |
| Dark Mystic | Weapon Mastery | 2 | 14 | 2,100 |
| Dark Mystic | Anti Magic | 1 | 7 | 480 |
| Dark Mystic | Anti Magic | 2 | 14 | 2,200 |
| Orc Mystic | Chill Flame | 1 | 1 | 0 |
| Orc Mystic | Chill Flame | 2 | 14 | 1,800 |
| Orc Mystic | Soul Cry | 1 | 1 | 50 |
| Orc Mystic | Soul Cry | 2 | 14 | 1,800 |
| Orc Mystic | Life Drain | 1 | 7 | 520 |
| Orc Mystic | Life Drain | 2 | 14 | 1,800 |
| Orc Mystic | Soul Shield | 1 | 7 | 520 |
| Orc Mystic | Robe Mastery | 1 | 7 | 520 |
| Orc Mystic | Robe Mastery | 2 | 14 | 1,760 |
| Orc Mystic | Weapon Mastery | 1 | 7 | 520 |
| Orc Mystic | Weapon Mastery | 2 | 14 | 1,800 |
| Orc Mystic | Anti Magic | 1 | 7 | 520 |
| Orc Mystic | Anti Magic | 2 | 14 | 1,760 |

Each skill's power and MP at each level (a burn's power is per second):

| Skill level | Power | MP |
|---|---|---|
| Power Strike 1 | 25 | 10 |
| Power Strike 2 | 30 | 11 |
| Power Strike 3 | 46 | 14 |
| Power Strike 4 | 70 | 19 |
| Mortal Blow 1 | 73 | 9 |
| Mortal Blow 2 | 88 | 10 |
| Mortal Blow 3 | 137 | 13 |
| Mortal Blow 4 | 210 | 17 |
| Power Shot 1 | 65 | 19 |
| Power Shot 2 | 78 | 21 |
| Power Shot 3 | 122 | 27 |
| Power Shot 4 | 187 | 37 |
| Iron Punch 1 | 29 | 11 |
| Iron Punch 2 | 34 | 13 |
| Iron Punch 3 | 54 | 16 |
| Iron Punch 4 | 82 | 22 |
| Wind Strike 1 | 12 | 9 |
| Wind Strike 2 | 15 | 10 |
| Wind Strike 3 | 21 | 15 |
| Ice Bolt 1 | 9 | 10 |
| Ice Bolt 2 | 13 | 15 |
| Vampiric Touch 1 | 21 | 28 |
| Chill Flame 1 | 20 | 15 |
| Chill Flame 2 | 30 | 23 |
| Drain Health 1 | 22 | 13 |
| Life Drain 1 | 15 | 27 |
| Life Drain 2 | 21 | 40 |
| Self Heal 1 | 42 | 9 |
| Heal 1 | 67 | 14 |
| Heal 2 | 107 | 22 |
| Elemental Heal 1 | 80 | 45 |
| Defense Aura 1 | | 5 |
| Attack Aura 1 | | 7 |
| Shield 1 | | 10 |
| Soul Shield 1 | | 10 |
| Curse: Poison 1 | 24 | 10 |
| Wind Shackle 1 | | 3 |
| Soul Cry 1 | 4.5 | 2 |
| Soul Cry 2 | 14 | 3 |
| Relax 1 | 5 | 3 |

What each line of a mastery adds (§19), and what must be worn for it:

| Passive line | Who | Stat | Adds | Worn |
|---|---|---|---|---|
| Armor Mastery 1 | | P. Def. | 9 | |
| Armor Mastery 2 | | P. Def. | 12 | |
| Armor Mastery 3 | | P. Def. | 14 | |
| Armor Mastery 3 | | Evasion | 3 | light armour |
| Robe Mastery 1 | | P. Def. | 13.4 | a robe |
| Robe Mastery 2 | | P. Def. | 18.4 | a robe |
| Weapon Mastery 1 | Fighter | P. Atk. | 8.5% | |
| Weapon Mastery 1 | Fighter | P. Atk. | 2 | |
| Weapon Mastery 2 | Fighter | P. Atk. | 8.5% | |
| Weapon Mastery 2 | Fighter | P. Atk. | 3 | |
| Weapon Mastery 3 | Fighter | P. Atk. | 8.5% | |
| Weapon Mastery 3 | Fighter | P. Atk. | 4 | |
| Weapon Mastery 1 | Mystic | P. Atk. | 45% | |
| Weapon Mastery 1 | Mystic | P. Atk. | 1.5 | |
| Weapon Mastery 1 | Mystic | M. Atk. | 17% | |
| Weapon Mastery 1 | Mystic | M. Atk. | 1.9 | |
| Weapon Mastery 2 | Mystic | P. Atk. | 45% | |
| Weapon Mastery 2 | Mystic | P. Atk. | 2.8 | |
| Weapon Mastery 2 | Mystic | M. Atk. | 17% | |
| Weapon Mastery 2 | Mystic | M. Atk. | 3.5 | |
| Anti Magic 1 | | M. Def. | 12 | |
| Anti Magic 2 | | M. Def. | 16 | |

A share multiplies (8.5% is × 1.085); Who names the path a line is for, where the two differ.

Example: a Human Fighter starts knowing Power Strike 1, whose level 1 its trainer teaches for
nothing, and at level 1 learns Mortal Blow 1 for **50** SP. At level 5 with 150 SP it learns Power
Strike 2 for 100, with 150 − 100 = **50** left, and its Power Strike strikes at power **30**. A Human
Mystic starts knowing Wind Strike and learns Self Heal for **50** SP.

Example: an Orc Fighter at level 15 in its Squire's Shirt and Pants has 89.51 P. Def. and 46 Evasion,
and knowing Armor Mastery 3, 89.51 + 14 = **103.51** and 46 + 3 = **49**. A Human Mystic at level 7
in its Apprentice's Tunic and Stockings has 59.92 P. Def., and knowing Robe Mastery 1, 59.92 + 13.4 =
**73.32**; with the tunic off it has **55.44**, Robe Mastery or not.

Example: an Orc Fighter at level 10 in its Squire's kit has 8.32 P. Atk. and 53.17 M. Def., and knowing
Weapon Mastery 2 and Anti Magic 1, 8.32 × 1.085 + 3 = **12.02** and 53.17 + 12 = **65.17**. A Human
Mystic at level 7 with its Apprentice's Wand has 9.45 M. Atk. and 3.02 P. Atk., and knowing Weapon
Mastery 1, 9.45 × 1.17 + 1.9 = **12.95** and 3.02 × 1.45 + 1.5 = **5.88**.

## 26. Potions

A potion heals its whole amount at once, never past the most, and stacks: a stack takes one place in
the inventory (§23) however many it holds, and is bought by the lot at its price each, sold whole for
half. In a fight (§20), at the start of each round, the character drinks the strongest potion it
carries if its HP is below the share it has chosen, at most one a round and at no cost to what it
does. The share is the player's: never, or below 30%, 50% or 70% of HP, and 50% to begin with. In
town a potion is drunk when the player says.

| Potion | Heals | Price | Sold |
|---|---|---|---|
| Lesser Healing Potion | 112 | 90 | village |

The starting villages sell the Lesser Healing Potion and nothing stronger. Better potions, and
potions for MP, are sold only in the towns further on, from the Town of Gludio.

Example: a character at 100 of 280 HP, below half, drinks a Lesser Healing Potion at the start of
the round and stands at **212**; ten cost **900** Adena.
