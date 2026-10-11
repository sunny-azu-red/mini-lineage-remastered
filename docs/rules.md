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
takes their place piece by piece: a weapon's P.Atk and M.Atk take the place of power and magic, and
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

- **P.Atk = (the weapon's P.Atk, or power) × STR bonus × level bonus**
- **M.Atk = (the weapon's M.Atk, or magic) × INT bonus² × level bonus²**
- **P.Def = body, each worn piece's count in place of its part, × level bonus**
- **M.Def = mind, the necklace's count in place of its part, × MEN bonus × level bonus**

Example: a level 1 Human Fighter has P.Atk 4 × 1.20 × 0.90 = **4.32**, P.Def 80 × 0.90 = **72** and
M.Def 41 × 1.28 × 0.90 = **47.2**. A level 1 Human Mystic has M.Atk 6 × 1.21² × 0.90² = **7.1**. In
its starting kit (§23) the Human Fighter has P.Atk 6 × 1.20 × 0.90 = **6.48** from its Squire's
Sword. Its Squire's Shirt (33) counts for 33 × 51 ÷ 31 = 54.3 and its Squire's Pants (20) for
20 × 25 ÷ 18 = 27.8, so its P.Def is (80 − 51 − 25 + 54.3 + 27.8) × 0.90 = **77.5**. A Necklace of
Wisdom (25) counts for 25 × 41 ÷ 13 = **78.8** of mind, nearly double the bare 41.

## 8. Accuracy and Evasion

**Accuracy = Evasion = √DEX × 6 + level**, rounded. A weapon's own accuracy (§24) is added to
Accuracy: a dagger or a bow −3, fists, a blunt or a staff +4, a sword 0.

Example: a level 1 Human Fighter, DEX 30: √30 × 6 + 1 = **34**, and with a Club **38**.

## 9. Critical

- **Critical % = the weapon's critical (4 bare-handed) × DEX bonus**, at most 50%.
- **Magic Critical % = 0.8 × WIT bonus**, at most 20%.

Example: a Human Fighter's DEX 30 gives 4 × 1.10 = **4.4%** bare-handed and 8 × 1.10 = **8.8%** with
a sword. A Human Mystic's WIT 20 gives
0.8 × 1.00 = **0.8%**.

## 10. Speed

- **Atk. Spd. = the weapon's speed (300 bare-handed) × DEX bonus**, rounded down, at most 1500.
- **Casting Spd. = 333 × WIT bonus**, rounded down, at most 1999.
- In a fight, a character strikes **Atk. Spd. ÷ 300** times a round and casts **Casting Spd. ÷ 333**
  times a round. A bow, which draws and then reloads, shoots **Atk. Spd. ÷ 610** times a round
  (Lineage II's 500,000 + 517,500 ÷ Atk. Spd. milliseconds a shot). A fraction carries over to the
  next round.

Example: a Human Fighter's DEX 30 gives Atk. Spd. **330** bare-handed, so **1.1** blows a round, and
379 × 1.10 = **416** with a sword. An Elven Fighter's DEX 35 draws a Short Bow at 293 × 1.15 =
**336**, so **0.55** shots a round.

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
- **Physical damage = 70 × P.Atk ÷ P.Def**, then spread by the weapon's own spread (§24) as a whole
  percentage either way, at least 1. Bare hands spread by 5 + √level, rounded down; a monster's
  blows by 10.
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

Example: a level 1 Dark Fighter (DEX 34) with its Dagger (−3, §8) has Accuracy 33 by day and
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
the least to the most. It fights in melee or with a bow (§10). The spells are §19's.

| Monster | Level | HP | MP | P.Atk | M.Atk | P.Def | M.Def | Atk. Spd. | DEX | EXP | SP | Adena | Attack | Spells |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Young Keltir | 1 | 62 | 44 | 9 | 3 | 39 | 32 | 278 | 30 | 35 | 2 | 8–12 at 70% | melee |  |
| Bearded Keltir | 1 | 62 | 44 | 9 | 3 | 39 | 32 | 278 | 30 | 35 | 2 | 8–12 at 70% | melee |  |
| Elpy | 1 | 62 | 44 | 9 | 3 | 39 | 32 | 278 | 30 | 35 | 2 | 8–12 at 70% | melee |  |
| Gremlin | 1 | 62 | 44 | 9 | 3 | 39 | 32 | 278 | 30 | 29 | 2 | 7–13 at 100% | melee |  |
| Elder Keltir | 3 | 90 | 60 | 12 | 3 | 40 | 35 | 278 | 30 | 105 | 2 | 13–20 at 70% | melee |  |
| Wolf | 4 | 107 | 68 | 12 | 4 | 46 | 37 | 278 | 30 | 141 | 4 | 19–29 at 70% | melee |  |
| Elder Wolf | 5 | 126 | 77 | 13 | 4 | 48 | 39 | 278 | 30 | 176 | 5 | 30–42 at 70% | melee |  |
| Giant Toad | 5 | 126 | 77 | 13 | 4 | 48 | 39 | 278 | 30 | 178 | 5 | 30–42 at 70% | melee |  |
| Orc | 6 | 147 | 85 | 15 | 5 | 50 | 41 | 278 | 30 | 213 | 6 | 41–58 at 70% | melee |  |
| Orc Grunt | 7 | 171 | 94 | 17 | 6 | 53 | 43 | 278 | 30 | 249 | 8 | 51–72 at 70% | melee |  |
| Goblin Scout | 8 | 197 | 102 | 18 | 6 | 55 | 45 | 278 | 30 | 284 | 10 | 67–91 at 70% | melee |  |
| Orc Archer | 8 | 197 | 102 | 41 | 6 | 55 | 45 | 249 | 30 | 293 | 10 | 69–94 at 70% | bow |  |
| Werewolf | 9 | 226 | 111 | 20 | 7 | 58 | 47 | 278 | 30 | 321 | 11 | 80–108 at 70% | melee |  |
| Orc Fighter | 10 | 257 | 120 | 22 | 8 | 61 | 49 | 278 | 30 | 363 | 12 | 98–132 at 70% | melee |  |
| Werewolf Hunter | 10 | 257 | 120 | 25 | 8 | 55 | 49 | 278 | 30 | 363 | 12 | 98–132 at 70% | melee |  |
| Orc Lieutenant | 11 | 292 | 129 | 23 | 9 | 70 | 52 | 278 | 30 | 391 | 15 | 109–147 at 70% | melee |  |
| Werewolf Chieftain | 12 | 315 | 138 | 30 | 10 | 60 | 54 | 278 | 30 | 436 | 16 | 114–157 at 70% | melee |  |
| Orc Fighter Leader | 12 | 315 | 138 | 30 | 10 | 60 | 54 | 278 | 30 | 447 | 17 | 117–161 at 70% | melee |  |
| Stone Golem | 13 | 339 | 147 | 30 | 11 | 70 | 56 | 278 | 30 | 654 | 26 | 127–180 at 70% | melee | NPC Windstrike - Slow 1 |
| Crasher | 14 | 364 | 156 | 30 | 12 | 80 | 59 | 278 | 30 | 705 | 27 | 128–189 at 70% | melee | NPC Windstrike - Slow 1 |
| Talon Spider | 16 | 417 | 174 | 44 | 15 | 72 | 64 | 278 | 30 | 570 | 23 | 118–183 at 70% | melee |  |
| Blade Spider | 17 | 446 | 184 | 48 | 17 | 75 | 67 | 278 | 30 | 618 | 26 | 122–197 at 70% | melee |  |
| Young Red Keltir | 1 | 62 | 44 | 9 | 3 | 39 | 32 | 278 | 30 | 35 | 2 | 8–12 at 70% | melee |  |
| Red Keltir | 2 | 75 | 52 | 10 | 3 | 42 | 34 | 278 | 30 | 70 | 2 | 8–13 at 70% | melee |  |
| Elder Red Keltir | 3 | 90 | 60 | 11 | 3 | 44 | 35 | 278 | 30 | 105 | 2 | 13–20 at 70% | melee |  |
| Gray Wolf | 4 | 107 | 68 | 12 | 4 | 46 | 37 | 278 | 30 | 141 | 4 | 19–29 at 70% | melee |  |
| Goblin Raider | 5 | 126 | 77 | 13 | 4 | 48 | 39 | 278 | 30 | 178 | 5 | 30–42 at 70% | melee |  |
| Kaboo Orc | 6 | 147 | 85 | 15 | 5 | 50 | 41 | 278 | 30 | 213 | 6 | 41–58 at 70% | melee |  |
| Kaboo Orc Grunt | 7 | 171 | 94 | 17 | 6 | 53 | 43 | 278 | 30 | 249 | 8 | 51–72 at 70% | melee |  |
| Green Dryad | 8 | 197 | 102 | 18 | 6 | 55 | 45 | 278 | 30 | 284 | 10 | 67–91 at 70% | melee |  |
| Kaboo Orc Archer | 8 | 197 | 102 | 41 | 6 | 55 | 45 | 249 | 30 | 293 | 10 | 69–94 at 70% | bow |  |
| Spore Fungus | 9 | 226 | 111 | 22 | 7 | 53 | 47 | 278 | 30 | 321 | 11 | 80–108 at 70% | melee |  |
| Kaboo Orc Fighter | 10 | 257 | 120 | 20 | 8 | 67 | 49 | 278 | 30 | 363 | 12 | 98–132 at 70% | melee |  |
| Baraq Orc Fighter | 10 | 257 | 120 | 25 | 8 | 55 | 49 | 278 | 30 | 302 | 10 | 81–110 at 70% | melee |  |
| Baraq Orc Warrior Leader | 11 | 292 | 129 | 27 | 9 | 58 | 52 | 278 | 30 | 326 | 12 | 91–122 at 70% | melee |  |
| Dungeon Skeleton | 12 | 315 | 138 | 26 | 10 | 60 | 54 | 317 | 30 | 363 | 13 | 95–131 at 70% | melee |  |
| Dungeon Skeleton Archer | 13 | 339 | 147 | 61 | 11 | 77 | 56 | 249 | 30 | 397 | 16 | 97–137 at 70% | bow |  |
| Dread Soldier | 14 | 364 | 156 | 32 | 12 | 66 | 59 | 317 | 30 | 424 | 16 | 97–143 at 70% | melee |  |
| Mist Terror | 15 | 390 | 165 | 40 | 14 | 69 | 62 | 278 | 30 | 454 | 19 | 99–150 at 70% | melee |  |
| Dark Terror | 16 | 417 | 174 | 44 | 15 | 72 | 64 | 278 | 30 | 533 | 22 | 110–171 at 70% | melee |  |
| Shade Horror | 17 | 446 | 184 | 48 | 17 | 75 | 67 | 278 | 30 | 504 | 21 | 100–161 at 70% | melee |  |
| Sukar Wererat | 18 | 476 | 193 | 46 | 19 | 79 | 70 | 317 | 30 | 533 | 23 | 101–167 at 70% | melee |  |
| Sukar Wererat Leader | 19 | 508 | 203 | 42 | 21 | 99 | 73 | 317 | 30 | 576 | 26 | 104–177 at 70% | melee |  |
| Dre Vanul Tracker | 20 | 541 | 213 | 63 | 23 | 86 | 76 | 278 | 30 | 605 | 27 | 106–184 at 70% | melee |  |
| Young Brown Keltir | 1 | 62 | 44 | 9 | 3 | 39 | 32 | 278 | 30 | 35 | 2 | 8–12 at 70% | melee |  |
| Brown Keltir | 2 | 75 | 52 | 10 | 3 | 42 | 34 | 278 | 30 | 70 | 2 | 8–13 at 70% | melee |  |
| Elder Brown Keltir | 3 | 90 | 60 | 11 | 3 | 44 | 35 | 278 | 30 | 105 | 2 | 13–20 at 70% | melee |  |
| Ashen Wolf | 4 | 107 | 68 | 12 | 4 | 46 | 37 | 278 | 30 | 141 | 4 | 19–29 at 70% | melee |  |
| Goblin | 5 | 126 | 77 | 13 | 4 | 48 | 39 | 278 | 30 | 178 | 5 | 30–42 at 70% | melee |  |
| Imp | 6 | 147 | 85 | 15 | 5 | 50 | 41 | 278 | 30 | 213 | 6 | 41–58 at 70% | melee |  |
| Imp Elder | 7 | 171 | 94 | 18 | 6 | 48 | 43 | 278 | 30 | 249 | 8 | 51–72 at 70% | melee |  |
| Balor Orc Archer | 8 | 197 | 102 | 41 | 6 | 55 | 45 | 249 | 30 | 293 | 10 | 69–94 at 70% | bow |  |
| Goblin Lookout | 8 | 197 | 102 | 16 | 6 | 55 | 45 | 317 | 30 | 284 | 10 | 67–91 at 70% | melee |  |
| Green Fungus | 9 | 226 | 111 | 22 | 7 | 53 | 47 | 278 | 30 | 321 | 11 | 80–108 at 70% | melee |  |
| Balor Orc Fighter | 10 | 257 | 120 | 25 | 8 | 55 | 49 | 278 | 30 | 363 | 12 | 98–132 at 70% | melee |  |
| Goblin Thief | 10 | 257 | 120 | 20 | 8 | 61 | 49 | 317 | 30 | 356 | 12 | 96–130 at 70% | melee |  |
| Vaiss Orc | 10 | 257 | 120 | 22 | 8 | 61 | 49 | 278 | 30 | 296 | 10 | 80–108 at 70% | melee |  |
| Balor Orc Lieutenant | 11 | 292 | 129 | 27 | 9 | 58 | 52 | 278 | 30 | 391 | 15 | 109–147 at 70% | melee |  |
| Vaiss Orc Warrior Leader | 11 | 292 | 129 | 27 | 9 | 58 | 52 | 278 | 30 | 326 | 12 | 91–122 at 70% | melee |  |
| Balor Orc Fighter Leader | 12 | 315 | 138 | 30 | 10 | 60 | 54 | 278 | 30 | 436 | 16 | 114–157 at 70% | melee |  |
| Blood Fungus | 12 | 315 | 138 | 30 | 10 | 60 | 54 | 278 | 30 | 427 | 16 | 112–154 at 70% | melee |  |
| Skeleton Hunter | 12 | 315 | 138 | 26 | 10 | 60 | 54 | 317 | 30 | 363 | 13 | 95–131 at 70% | melee |  |
| Doom Soldier | 14 | 364 | 156 | 32 | 12 | 66 | 59 | 317 | 30 | 424 | 16 | 97–143 at 70% | melee |  |
| Cave Spider | 15 | 390 | 165 | 40 | 14 | 69 | 62 | 278 | 30 | 445 | 18 | 97–147 at 70% | melee |  |
| Cave Fang Spider | 16 | 417 | 174 | 44 | 15 | 72 | 64 | 278 | 30 | 485 | 20 | 100–156 at 70% | melee |  |
| Omen Beast | 17 | 446 | 184 | 48 | 17 | 75 | 67 | 278 | 30 | 504 | 21 | 100–161 at 70% | melee |  |
| Tainted Zombie | 18 | 476 | 193 | 44 | 19 | 95 | 70 | 278 | 30 | 754 | 33 | 114–187 at 70% | melee |  |
| Stink Zombie | 19 | 508 | 203 | 48 | 21 | 99 | 73 | 278 | 30 | 799 | 36 | 115–195 at 70% | melee | NPC HP Drain - Slow 1 |
| Lesser Succubus | 20 | 541 | 213 | 57 | 23 | 94 | 76 | 278 | 30 | 605 | 27 | 106–184 at 70% | melee |  |
| Lesser Succubus Turen | 21 | 575 | 227 | 69 | 25 | 89 | 80 | 278 | 30 | 649 | 30 | 110–197 at 70% | melee | NPC HP Drain - Magic 2, NPC Aura Burn - Magic 2 |
| Lesser Succubus Tilfo | 22 | 611 | 242 | 75 | 28 | 93 | 83 | 278 | 30 | 698 | 33 | 116–209 at 70% | melee |  |
| Young Prairie Keltir | 1 | 62 | 44 | 9 | 3 | 39 | 32 | 278 | 30 | 35 | 2 | 8–12 at 70% | melee |  |
| Prairie Keltir | 2 | 75 | 52 | 10 | 3 | 42 | 34 | 278 | 30 | 70 | 2 | 8–13 at 70% | melee |  |
| Elder Prairie Keltir | 3 | 90 | 60 | 11 | 3 | 44 | 35 | 278 | 30 | 105 | 2 | 13–20 at 70% | melee |  |
| Kasha Wolf | 4 | 107 | 68 | 12 | 4 | 46 | 37 | 278 | 30 | 141 | 4 | 19–29 at 70% | melee |  |
| Goblin Grave Robber | 5 | 126 | 77 | 13 | 4 | 48 | 39 | 278 | 30 | 178 | 5 | 30–42 at 70% | melee |  |
| Rakeclaw Imp | 6 | 147 | 85 | 16 | 5 | 46 | 41 | 278 | 30 | 213 | 6 | 41–58 at 70% | melee |  |
| Kasha Timber Wolf | 6 | 147 | 85 | 15 | 5 | 50 | 41 | 278 | 30 | 211 | 6 | 41–58 at 70% | melee |  |
| Rakeclaw Imp Hunter | 7 | 171 | 94 | 18 | 6 | 48 | 43 | 278 | 30 | 249 | 8 | 51–72 at 70% | melee |  |
| Mountain Fungus | 8 | 197 | 102 | 20 | 6 | 50 | 45 | 278 | 30 | 284 | 10 | 67–91 at 70% | melee |  |
| Maraku Werewolf | 9 | 226 | 111 | 22 | 7 | 53 | 47 | 278 | 30 | 321 | 11 | 80–108 at 70% | melee |  |
| Evil Eye | 10 | 257 | 120 | 20 | 8 | 67 | 49 | 278 | 30 | 356 | 12 | 96–130 at 70% | melee | NPC Windstrike - Magic 1, NPC Aura Burn - Magic 1 |
| Evil Eye Watcher | 10 | 257 | 120 | 20 | 8 | 67 | 49 | 278 | 30 | 296 | 10 | 80–108 at 70% | melee | NPC HP Drain - Magic 1, NPC Aura Burn - Magic 1 |
| Darkwing Bat | 11 | 292 | 129 | 27 | 9 | 58 | 52 | 278 | 30 | 391 | 15 | 109–147 at 70% | melee |  |
| Grizzly | 12 | 315 | 138 | 27 | 10 | 66 | 54 | 278 | 30 | 436 | 16 | 114–157 at 70% | melee |  |
| Goblin Tomb Raider Leader | 12 | 315 | 138 | 24 | 10 | 66 | 54 | 317 | 30 | 427 | 16 | 112–154 at 70% | melee |  |
| Slave Skeleton | 12 | 315 | 138 | 26 | 10 | 60 | 54 | 317 | 30 | 363 | 13 | 95–131 at 70% | melee |  |
| Greystone Golem | 13 | 339 | 147 | 27 | 11 | 77 | 56 | 278 | 30 | 654 | 26 | 127–180 at 70% | melee | NPC Prominence - Slow 1 |
| Grave Keeper | 13 | 339 | 147 | 27 | 11 | 77 | 56 | 278 | 30 | 545 | 21 | 106–150 at 70% | melee | NPC Windstrike - Slow 1 |
| Evil Eye Patroller | 14 | 364 | 156 | 30 | 12 | 80 | 59 | 278 | 30 | 498 | 19 | 114–168 at 70% | melee | NPC Windstrike - Magic 1, NPC Aura Burn - Magic 1 |
| Crypt Horror | 15 | 390 | 165 | 40 | 14 | 69 | 62 | 278 | 30 | 454 | 19 | 99–150 at 70% | melee |  |
| Kuruka Ratman | 16 | 417 | 174 | 32 | 15 | 87 | 64 | 317 | 30 | 475 | 19 | 98–153 at 70% | melee |  |
| Kuruka Ratman Hunter | 17 | 446 | 184 | 40 | 17 | 91 | 67 | 278 | 30 | 504 | 21 | 100–161 at 70% | melee |  |
| Skeleton Longbowman | 19 | 508 | 203 | 129 | 21 | 82 | 73 | 249 | 30 | 587 | 26 | 106–181 at 70% | bow |  |
| Undead Slave | 19 | 508 | 203 | 58 | 21 | 82 | 73 | 278 | 30 | 799 | 36 | 115–195 at 70% | melee | NPC Windstrike - Slow 1 |
| Ghost | 20 | 541 | 213 | 63 | 23 | 86 | 76 | 278 | 30 | 599 | 27 | 105–183 at 70% | melee |  |
| Ghost Guardian | 21 | 575 | 227 | 63 | 25 | 98 | 80 | 278 | 30 | 643 | 30 | 109–195 at 70% | melee |  |

Example: a Young Keltir (DEX 30, level 1) has Accuracy and Evasion √30 × 6 + 1 = **34** and a
**4.4%** Critical.

## 19. Skills

Every set starts with one skill from its own tree, and each race's is different. Each costs MP and
then rests for its reuse.

| Skill | Set | Kind | Power | MP | Reuse | Cast |
|---|---|---|---|---|---|---|
| Power Strike | Human Fighter | physical | 25 | 10 | 13,000 | |
| Power Shot | Elven Fighter | physical | 65 | 19 | 25,000 | |
| Mortal Blow | Dark Fighter | blow | 73 | 9 | 11,000 | |
| Iron Punch | Orc Fighter | physical | 29 | 11 | 15,000 | |
| Wind Strike | Human Mystic | magic | 12 | 9 | 6,000 | 4,000 |
| Ice Bolt | Elven Mystic | magic | 8 | 9 | 8,000 | 3,300 |
| Vampiric Touch | Dark Mystic | drain | 18 | 25 | 12,000 | 4,000 |
| Chill Flame | Orc Mystic | burn | 20 | 15 | 6,000 | 4,000 |

Reuse and cast are in milliseconds. The reuse is × 333 ÷ Atk. Spd. for a physical skill or a blow
and × 333 ÷ Casting Spd. for the rest, and a cast is × 333 ÷ Casting Spd. A physical skill takes
the place of a blow and has no cast of its own.

- **Physical:** 70 × (P.Atk + power) ÷ P.Def, then the weapon's spread (§13). It never misses and
  never lands a critical.
- **Blow:** the same damage, landing 40% × the DEX bonus of the time, at most 80%, and otherwise
  doing nothing.
- **Magic:** §13's magic damage, which can be a magic critical. A spell never misses.
- **Drain:** magic damage, healing the caster 40% of what the target lost.
- **Burn:** power HP a second for 15 seconds, which never takes the last HP. It is not cast again on
  a target that still burns.
- **Ice Bolt** also slows its target for 120 seconds, and a slowed monster swings 30% less.

Monsters cast these:

| Spell | Kind | Power | MP | Reuse | Cast |
|---|---|---|---|---|---|
| NPC Windstrike - Magic 1 | magic | 18 | 7 | 3,000 | 4,000 |
| NPC HP Drain - Magic 1 | drain | 18 | 9 | 3,000 | 4,000 |
| NPC HP Drain - Magic 2 | drain | 26 | 14 | 3,000 | 4,000 |
| NPC Aura Burn - Magic 1 | magic | 5 | 3 | 1,000 | 1,500 |
| NPC Aura Burn - Magic 2 | magic | 7 | 3 | 1,000 | 1,500 |
| NPC Windstrike - Slow 1 | magic | 5 | 13 | 8,000 | 2,000 |
| NPC Windstrike - Slow 2 | magic | 8 | 20 | 8,000 | 2,000 |
| NPC HP Drain - Slow 1 | drain | 5 | 17 | 8,000 | 2,000 |
| NPC Prominence - Slow 1 | magic | 5 | 13 | 8,000 | 2,000 |

A monster's drain heals it 20% of what the character lost.

Example: a level 1 Human Fighter with its Squire's Sword (P.Atk 6.48) strikes a Young Keltir (P.Def
39) with Power Strike for 70 × (6.48 + 25) ÷ 39 = **56.5** before the ±10%, where a blow does
**11.6**. A Dark Fighter's DEX 34 lands Mortal Blow 40 × 1.14 = **45.6%** of the time. The Human
Fighter's Atk. Spd. 416 rests Power Strike 13,000 × 333 ÷ 416 = **10,406** milliseconds.

## 20. The hunt

One click, one fight. Each village's ground (§17) is hunted from the village, a monster at a time.

- **Who you meet:** one of the ground's monsters from 3 levels below the character up to its own
  level, each as likely as the next, or one of the nearest if none is. Nothing on a village's ground
  is ever stronger than the character who meets it there.
- **A round** is 1⅔ seconds, one blow at 300 Atk. Spd. (Lineage II's 500,000 ÷ Atk. Spd.
  milliseconds). The character acts, then the monster if it still stands, and a skill's reuse runs
  down by 1⅔ seconds each round.
- **The character** swings its blows (§10). A Fighter's skill takes the first blow of a round once its
  reuse has run out and its MP is paid. A Mystic whose spell is ready casts it instead, and does
  nothing else for the spell's cast time (§19), × 333 ÷ Casting Spd.; it swings when no spell is
  ready.
- **The monster** swings its blows the same way, at its own Atk. Spd., and a monster with a bow
  draws and reloads as a character's bow does (§10). A monster with spells casts the strongest that
  is ready instead, and does nothing else for its cast time. Its reuse and cast time are not
  scaled.
- **Blows** hit and do damage as §13 says. Skills and spells do what §19 says.
- **It ends** when either reaches 0 HP. After 1,000 rounds the monster wanders off and pays nothing.
- **The reward** for a kill is the monster's EXP and SP (§12) and its Adena, each × its server rate
  (§22). A character more than 5 levels above the monster earns × (5 ÷ 6) for each level past the
  fifth, rounded down.
- **What is left** of HP and MP stays, and rest (§11) goes on refilling it.

Example: a level 12 character who kills a Young Keltir (level 1, 35 EXP) is 11 levels above it, 6 past
the fifth, and earns 35 × 5 × (5 ÷ 6)⁶ = 58.6, so **58** EXP. A level 6 character earns all of it,
**175**.

## 21. Death

At 0 HP the run is over. The character is written as fallen, with what killed it and where, and
nothing of it carries over: the browser goes back to game start for the next one. It keeps its place
on the Monument of Heroes, which ranks every run by EXP and so by level, then EXP, then Adena.

Example: a level 9 run with 40,000 EXP that dies stands above every level 8 run, and above a level 9
run with 39,999 EXP.

## 22. Server rates

Every Lineage II server ran at rates, multiplying what monsters pay. This one runs at:

| Rate | Times |
|---|---|
| EXP | 5 |
| SP | 5 |
| Adena | 20 |

Adena runs four times faster than EXP because the village shops price their gear for a game where
most Adena came from quests and from selling what monsters dropped, and the hunt has neither. A
seeded run of every set up its village's ladder takes about 310 to 390 kills from level 1 to 20, and
holds about 55,000 Adena at level 11 and 250,000 at level 16, where a Gladius costs 62,215 and a Long
Sword 156,400.

Example: a Young Keltir carrying 10 Adena pays **200**.

## 23. Gear

A character carries up to 80 items and wears at most one in each of five slots: weapon, shield,
chest, legs and necklace. A two-handed weapon (a bow, a staff, fists,
a two-handed sword or blunt, a polearm) takes the shield's hand, so putting one on takes the shield
off, and the other way round. Nothing is weighed.

Every set starts with its kit, the wearable part worn:

| Kit | Worn | Carried |
|---|---|---|
| Human Fighter | Squire's Sword, Squire's Shirt, Squire's Pants | Dagger |
| Elven Fighter | Short Bow, Squire's Shirt, Squire's Pants | Squire's Sword |
| Dark Fighter | Dagger, Squire's Shirt, Squire's Pants | Squire's Sword |
| Orc Fighter | Training Gloves, Squire's Shirt, Squire's Pants | Squire's Sword |
| Human Mystic | Apprentice's Wand, Apprentice's Tunic, Apprentice's Stockings | |
| Elven Mystic | Apprentice's Wand, Apprentice's Tunic, Apprentice's Stockings | |
| Dark Mystic | Apprentice's Wand, Apprentice's Tunic, Apprentice's Stockings | |
| Orc Mystic | Training Gloves, Apprentice's Tunic, Apprentice's Stockings | |

- **A first skill (§19) needs its weapon:** Power Strike a sword or a blunt, Power Shot a bow, Mortal
  Blow a dagger, Iron Punch fists. Without it the character only swings. Spells need none.
- **A shield** catches a monster's blow at its block rate × the DEX bonus, as a percentage. A catch
  adds the shield's defence to P.Def for that blow, and one catch in twenty is perfect and takes only
  1. Spells pass a shield by.
- **A robe's MP** is added to Max MP (§6).

Example: a Human Fighter (DEX 30) behind a Small Shield (defence 56, block 20) catches 20 × 1.10 =
**22%** of the blows aimed at it. A Human Mystic's starting robes add 19 + 10 = **29** Max MP.

## 24. Village shops

Every starting village sells the items marked village below, and Orc Village those marked
orc-village too, each at its price plus 15% tax, rounded down. A shop buys back anything it sells
for half its price, rounded down. A starting kit is worth nothing to a shop and is never bought.

| Item | Kind | Slot | Hands | Type | P.Atk | M.Atk | Atk. Spd. | Critical | Accuracy | Spread | P.Def | M.Def | Shield | Block | MP | Price | Sold |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Apprentice's Wand | weapon | weapon | 1 | blunt | 5 | 7 | 379 | 4 | 4 | 20 |  |  |  |  |  | 138 | starting |
| Club | weapon | weapon | 1 | blunt | 8 | 6 | 379 | 4 | 4 | 20 |  |  |  |  |  | 768 | village |
| Apprentice's Rod | weapon | weapon | 1 | blunt | 6 | 8 | 379 | 4 | 4 | 20 |  |  |  |  |  | 768 | village |
| Heavy Chisel | weapon | weapon | 1 | blunt | 10 | 8 | 379 | 4 | 4 | 20 |  |  |  |  |  | 8070 | village |
| Mace | weapon | weapon | 1 | blunt | 11 | 9 | 379 | 4 | 4 | 20 |  |  |  |  |  | 12500 | village |
| Sickle | weapon | weapon | 1 | blunt | 12 | 9 | 379 | 4 | 4 | 20 |  |  |  |  |  | 18500 | village |
| Dwarven Mace | weapon | weapon | 1 | blunt | 17 | 12 | 379 | 4 | 4 | 20 |  |  |  |  |  | 54100 | village |
| Short Bow | weapon | weapon | 2 | bow | 16 | 6 | 293 | 12 | -3 | 5 |  |  |  |  |  | 768 | village |
| Bow | weapon | weapon | 2 | bow | 23 | 9 | 293 | 12 | -3 | 5 |  |  |  |  |  | 12500 | village |
| Hunting Bow | weapon | weapon | 2 | bow | 34 | 12 | 293 | 12 | -3 | 5 |  |  |  |  |  | 54100 | village |
| Forest Bow | weapon | weapon | 2 | bow | 49 | 17 | 293 | 12 | -3 | 5 |  |  |  |  |  | 136000 | village |
| Dagger | weapon | weapon | 1 | dagger | 5 | 5 | 433 | 12 | -3 | 5 |  |  |  |  |  | 138 | starting |
| Bone Dagger | weapon | weapon | 1 | dagger | 7 | 6 | 433 | 12 | -3 | 5 |  |  |  |  |  | 768 | village |
| Knife | weapon | weapon | 1 | dagger | 10 | 9 | 433 | 12 | -3 | 5 |  |  |  |  |  | 12500 | village |
| Doom Dagger | weapon | weapon | 1 | dagger | 10 | 9 | 433 | 12 | -3 | 5 |  |  |  |  |  | 12500 | village |
| Dirk | weapon | weapon | 1 | dagger | 15 | 12 | 433 | 12 | -3 | 5 |  |  |  |  |  | 54100 | village |
| Throwing Knife | weapon | weapon | 1 | dagger | 21 | 17 | 433 | 12 | -3 | 5 |  |  |  |  |  | 136000 | village |
| Training Gloves | weapon | weapon | 2 | fists | 7 | 5 | 325 | 4 | 4 | 5 |  |  |  |  |  | 138 | starting |
| Spiked Gloves | weapon | weapon | 2 | fists | 10 | 6 | 325 | 4 | 4 | 5 |  |  |  |  |  | 768 | orc-village |
| Iron Gloves | weapon | weapon | 2 | fists | 13 | 9 | 325 | 4 | 4 | 5 |  |  |  |  |  | 12500 | orc-village |
| Fox Claw Gloves | weapon | weapon | 2 | fists | 21 | 12 | 325 | 4 | 4 | 5 |  |  |  |  |  | 54100 | orc-village |
| Cestus | weapon | weapon | 2 | fists | 29 | 17 | 325 | 4 | 4 | 5 |  |  |  |  |  | 136000 | orc-village |
| Short Spear | weapon | weapon | 2 | pole | 24 | 17 | 325 | 8 | -3 | 10 |  |  |  |  |  | 136000 | village |
| Buffalo's Horn | weapon | weapon | 1 | staff | 6 | 8 | 379 | 8 | 0 | 10 |  |  |  |  |  | 768 | village |
| Apprentice's Spellbook | weapon | weapon | 1 | staff | 9 | 12 | 379 | 8 | 0 | 10 |  |  |  |  |  | 12500 | village |
| Relic of The Saints | weapon | weapon | 1 | staff | 19 | 22 | 379 | 8 | 0 | 10 |  |  |  |  |  | 136000 | village |
| Squire's Sword | weapon | weapon | 1 | sword | 6 | 5 | 379 | 8 | 0 | 10 |  |  |  |  |  | 138 | starting |
| Short Sword | weapon | weapon | 1 | sword | 8 | 6 | 379 | 8 | 0 | 10 |  |  |  |  |  | 768 | village |
| Broadsword | weapon | weapon | 1 | sword | 11 | 9 | 379 | 8 | 0 | 10 |  |  |  |  |  | 12500 | village |
| Gladius | weapon | weapon | 1 | sword | 17 | 12 | 379 | 8 | 0 | 10 |  |  |  |  |  | 54100 | village |
| Orcish Sword | weapon | weapon | 1 | sword | 17 | 12 | 379 | 8 | 0 | 10 |  |  |  |  |  | 54100 | village |
| Handmade Sword | weapon | weapon | 1 | sword | 17 | 12 | 379 | 8 | 0 | 10 |  |  |  |  |  | 54100 | village |
| Long Sword | weapon | weapon | 1 | sword | 24 | 17 | 379 | 8 | 0 | 10 |  |  |  |  |  | 136000 | village |
| Willow Staff | weapon | weapon | 2 | two-handed blunt | 11 | 12 | 325 | 4 | 4 | 20 |  |  |  |  |  | 12500 | village |
| Cedar Staff | weapon | weapon | 2 | two-handed blunt | 16 | 16 | 325 | 4 | 4 | 20 |  |  |  |  |  | 54100 | village |
| Journeyman's Staff | weapon | weapon | 2 | two-handed blunt | 23 | 22 | 325 | 4 | 4 | 20 |  |  |  |  |  | 136000 | village |
| Brandish | weapon | weapon | 2 | two-handed sword | 21 | 12 | 325 | 8 | 0 | 10 |  |  |  |  |  | 54100 | village |
| Zweihander | weapon | weapon | 2 | two-handed sword | 38 | 21 | 325 | 8 | 0 | 10 |  |  |  |  |  | 244000 | village |
| Leather Shield | shield | shield |  |  |  |  |  |  |  |  |  |  | 47 | 20 |  | 39 | village |
| Small Shield | shield | shield |  |  |  |  |  |  |  |  |  |  | 56 | 20 |  | 638 | village |
| Buckler | shield | shield |  |  |  |  |  |  |  |  |  |  | 67 | 20 |  | 2780 | village |
| Round Shield | shield | shield |  |  |  |  |  |  |  |  |  |  | 79 | 20 |  | 7110 | village |
| Squire's Shirt | armour | chest |  | light |  |  |  |  |  |  | 33 |  |  |  |  | 26 | starting |
| Shirt | armour | chest |  | light |  |  |  |  |  |  | 36 |  |  |  |  | 147 | village |
| Leather Shirt | armour | chest |  | light |  |  |  |  |  |  | 43 |  |  |  |  | 2430 | village |
| Wooden Breastplate | armour | chest |  | light |  |  |  |  |  |  | 47 |  |  |  |  | 7960 | village |
| Cotton Shirt | armour | chest |  | light |  |  |  |  |  |  | 50 |  |  |  |  | 20300 | village |
| Bone Breastplate | armour | chest |  | light |  |  |  |  |  |  | 50 |  |  |  |  | 20300 | village |
| Apprentice's Tunic | armour | chest |  | magic |  |  |  |  |  |  | 17 |  |  |  | 19 | 26 | starting |
| Tunic | armour | chest |  | magic |  |  |  |  |  |  | 18 |  |  |  | 24 | 147 | village |
| Cotton Tunic | armour | chest |  | magic |  |  |  |  |  |  | 21 |  |  |  | 38 | 2430 | village |
| Feriotic Tunic | armour | chest |  | magic |  |  |  |  |  |  | 21 |  |  |  | 38 | 2430 | village |
| Leather Tunic | armour | chest |  | magic |  |  |  |  |  |  | 25 |  |  |  | 52 | 7960 | village |
| Tunic of Devotion | armour | chest |  | magic |  |  |  |  |  |  | 30 |  |  |  | 67 | 20300 | village |
| Squire's Pants | armour | legs |  | light |  |  |  |  |  |  | 20 |  |  |  |  | 6 | starting |
| Pants | armour | legs |  | light |  |  |  |  |  |  | 22 |  |  |  |  | 92 | village |
| Leather Pants | armour | legs |  | light |  |  |  |  |  |  | 27 |  |  |  |  | 1520 | village |
| Hard Leather Pants | armour | legs |  | light |  |  |  |  |  |  | 29 |  |  |  |  | 4970 | village |
| Wooden Gaiters | armour | legs |  | light |  |  |  |  |  |  | 29 |  |  |  |  | 4970 | village |
| Cotton Pants | armour | legs |  | light |  |  |  |  |  |  | 32 |  |  |  |  | 12700 | village |
| Bone Gaiters | armour | legs |  | light |  |  |  |  |  |  | 32 |  |  |  |  | 12700 | village |
| Apprentice's Stockings | armour | legs |  | magic |  |  |  |  |  |  | 10 |  |  |  | 10 | 6 | starting |
| Stockings | armour | legs |  | magic |  |  |  |  |  |  | 11 |  |  |  | 15 | 92 | village |
| Cotton Stockings | armour | legs |  | magic |  |  |  |  |  |  | 13 |  |  |  | 23 | 1520 | village |
| Feriotic Stockings | armour | legs |  | magic |  |  |  |  |  |  | 13 |  |  |  | 23 | 1520 | village |
| Leather Stockings | armour | legs |  | magic |  |  |  |  |  |  | 16 |  |  |  | 33 | 4970 | village |
| Stockings of Devotion | armour | legs |  | magic |  |  |  |  |  |  | 19 |  |  |  | 42 | 12700 | village |
| Necklace of Magic | jewellery | necklace |  |  |  |  |  |  |  |  |  | 15 |  |  |  | 66 | village |
| Necklace of Knowledge | jewellery | necklace |  |  |  |  |  |  |  |  |  | 18 |  |  |  | 1080 | village |
| Necklace of Anguish | jewellery | necklace |  |  |  |  |  |  |  |  |  | 21 |  |  |  | 4680 | village |
| Necklace of Wisdom | jewellery | necklace |  |  |  |  |  |  |  |  |  | 25 |  |  |  | 11900 | village |

Example: a Broadsword (12,500) costs 12,500 × 1.15 = **14,375** and sells back for **6,250**.

## 25. The trainer

Each starting village's trainers teach its own race and nobody else, for the SP a character earns
on the hunt (§20). A line is learned once the character has reached its level, knows the level
before it, and pays its SP. Each set's list is short: its first skill's later levels and the
masteries its tree holds before the class change.

| Set | Skill | Level | From level | SP |
|---|---|---|---|---|
| Human Fighter | Power Strike | 2 | 5 | 50 |
| Human Fighter | Power Strike | 3 | 5 | 50 |
| Human Fighter | Power Strike | 4 | 10 | 370 |
| Human Fighter | Power Strike | 5 | 10 | 370 |
| Human Fighter | Power Strike | 6 | 10 | 370 |
| Human Fighter | Power Strike | 7 | 15 | 1,300 |
| Human Fighter | Power Strike | 8 | 15 | 1,300 |
| Human Fighter | Power Strike | 9 | 15 | 1,300 |
| Human Fighter | Weapon Mastery | 1 | 5 | 160 |
| Human Fighter | Weapon Mastery | 2 | 10 | 1,100 |
| Human Fighter | Weapon Mastery | 3 | 15 | 4,000 |
| Human Fighter | Armor Mastery | 1 | 5 | 160 |
| Human Fighter | Armor Mastery | 2 | 10 | 550 |
| Human Fighter | Armor Mastery | 3 | 10 | 550 |
| Human Fighter | Armor Mastery | 4 | 15 | 2,000 |
| Human Fighter | Armor Mastery | 5 | 15 | 2,000 |
| Elven Fighter | Power Shot | 2 | 5 | 50 |
| Elven Fighter | Power Shot | 3 | 5 | 50 |
| Elven Fighter | Power Shot | 4 | 10 | 310 |
| Elven Fighter | Power Shot | 5 | 10 | 310 |
| Elven Fighter | Power Shot | 6 | 10 | 310 |
| Elven Fighter | Power Shot | 7 | 15 | 1,100 |
| Elven Fighter | Power Shot | 8 | 15 | 1,100 |
| Elven Fighter | Power Shot | 9 | 15 | 1,100 |
| Elven Fighter | Weapon Mastery | 1 | 5 | 160 |
| Elven Fighter | Weapon Mastery | 2 | 10 | 910 |
| Elven Fighter | Weapon Mastery | 3 | 15 | 3,300 |
| Elven Fighter | Armor Mastery | 1 | 5 | 160 |
| Elven Fighter | Armor Mastery | 2 | 10 | 460 |
| Elven Fighter | Armor Mastery | 3 | 10 | 460 |
| Elven Fighter | Armor Mastery | 4 | 15 | 1,700 |
| Elven Fighter | Armor Mastery | 5 | 15 | 1,700 |
| Dark Fighter | Mortal Blow | 2 | 5 | 50 |
| Dark Fighter | Mortal Blow | 3 | 5 | 50 |
| Dark Fighter | Mortal Blow | 4 | 10 | 310 |
| Dark Fighter | Mortal Blow | 5 | 10 | 310 |
| Dark Fighter | Mortal Blow | 6 | 10 | 310 |
| Dark Fighter | Mortal Blow | 7 | 15 | 950 |
| Dark Fighter | Mortal Blow | 8 | 15 | 950 |
| Dark Fighter | Mortal Blow | 9 | 15 | 950 |
| Dark Fighter | Weapon Mastery | 1 | 5 | 160 |
| Dark Fighter | Weapon Mastery | 2 | 10 | 910 |
| Dark Fighter | Weapon Mastery | 3 | 15 | 2,900 |
| Dark Fighter | Armor Mastery | 1 | 5 | 160 |
| Dark Fighter | Armor Mastery | 2 | 10 | 460 |
| Dark Fighter | Armor Mastery | 3 | 10 | 460 |
| Dark Fighter | Armor Mastery | 4 | 15 | 1,400 |
| Dark Fighter | Armor Mastery | 5 | 15 | 1,400 |
| Orc Fighter | Iron Punch | 2 | 5 | 60 |
| Orc Fighter | Iron Punch | 3 | 5 | 60 |
| Orc Fighter | Iron Punch | 4 | 10 | 460 |
| Orc Fighter | Iron Punch | 5 | 10 | 460 |
| Orc Fighter | Iron Punch | 6 | 10 | 460 |
| Orc Fighter | Iron Punch | 7 | 15 | 1,300 |
| Orc Fighter | Iron Punch | 8 | 15 | 1,300 |
| Orc Fighter | Iron Punch | 9 | 15 | 1,300 |
| Orc Fighter | Weapon Mastery | 1 | 5 | 190 |
| Orc Fighter | Weapon Mastery | 2 | 10 | 1,300 |
| Orc Fighter | Weapon Mastery | 3 | 15 | 4,000 |
| Orc Fighter | Armor Mastery | 1 | 5 | 190 |
| Orc Fighter | Armor Mastery | 2 | 10 | 690 |
| Orc Fighter | Armor Mastery | 3 | 10 | 690 |
| Orc Fighter | Armor Mastery | 4 | 15 | 2,000 |
| Orc Fighter | Armor Mastery | 5 | 15 | 2,000 |
| Human Mystic | Wind Strike | 2 | 7 | 240 |
| Human Mystic | Wind Strike | 3 | 7 | 240 |
| Human Mystic | Wind Strike | 4 | 14 | 1,100 |
| Human Mystic | Wind Strike | 5 | 14 | 1,100 |
| Elven Mystic | Ice Bolt | 2 | 7 | 260 |
| Elven Mystic | Ice Bolt | 3 | 14 | 1,100 |
| Elven Mystic | Ice Bolt | 4 | 14 | 1,100 |
| Dark Mystic | Vampiric Touch | 2 | 14 | 1,100 |
| Orc Mystic | Chill Flame | 2 | 14 | 1,800 |
| Human Mystic | Weapon Mastery | 1 | 7 | 470 |
| Human Mystic | Weapon Mastery | 2 | 14 | 2,100 |
| Human Mystic | Anti Magic | 1 | 7 | 240 |
| Human Mystic | Anti Magic | 2 | 7 | 240 |
| Human Mystic | Anti Magic | 3 | 14 | 1,100 |
| Human Mystic | Anti Magic | 4 | 14 | 1,100 |
| Human Mystic | Armor Mastery | 1 | 7 | 470 |
| Human Mystic | Armor Mastery | 2 | 14 | 1,100 |
| Human Mystic | Armor Mastery | 3 | 14 | 1,100 |
| Elven Mystic | Weapon Mastery | 1 | 7 | 520 |
| Elven Mystic | Weapon Mastery | 2 | 14 | 2,100 |
| Elven Mystic | Anti Magic | 1 | 7 | 260 |
| Elven Mystic | Anti Magic | 2 | 7 | 260 |
| Elven Mystic | Anti Magic | 3 | 14 | 1,100 |
| Elven Mystic | Anti Magic | 4 | 14 | 1,100 |
| Elven Mystic | Armor Mastery | 1 | 7 | 520 |
| Elven Mystic | Armor Mastery | 2 | 14 | 1,100 |
| Elven Mystic | Armor Mastery | 3 | 14 | 1,100 |
| Dark Mystic | Weapon Mastery | 1 | 7 | 470 |
| Dark Mystic | Weapon Mastery | 2 | 14 | 2,100 |
| Dark Mystic | Anti Magic | 1 | 7 | 240 |
| Dark Mystic | Anti Magic | 2 | 7 | 240 |
| Dark Mystic | Anti Magic | 3 | 14 | 1,100 |
| Dark Mystic | Anti Magic | 4 | 14 | 1,100 |
| Dark Mystic | Armor Mastery | 1 | 7 | 470 |
| Dark Mystic | Armor Mastery | 2 | 14 | 1,100 |
| Dark Mystic | Armor Mastery | 3 | 14 | 1,100 |
| Orc Mystic | Weapon Mastery | 1 | 7 | 520 |
| Orc Mystic | Weapon Mastery | 2 | 14 | 1,800 |
| Orc Mystic | Anti Magic | 1 | 7 | 260 |
| Orc Mystic | Anti Magic | 2 | 7 | 260 |
| Orc Mystic | Anti Magic | 3 | 14 | 880 |
| Orc Mystic | Anti Magic | 4 | 14 | 880 |
| Orc Mystic | Robe Mastery | 1 | 7 | 260 |
| Orc Mystic | Robe Mastery | 2 | 7 | 260 |
| Orc Mystic | Robe Mastery | 3 | 14 | 880 |
| Orc Mystic | Robe Mastery | 4 | 14 | 880 |

A first skill's power and MP at each level (a burn's power is per second):

| Skill level | Power | MP |
|---|---|---|
| Power Strike 1 | 25 | 10 |
| Power Strike 2 | 27 | 10 |
| Power Strike 3 | 30 | 11 |
| Power Strike 4 | 39 | 13 |
| Power Strike 5 | 42 | 13 |
| Power Strike 6 | 46 | 14 |
| Power Strike 7 | 60 | 17 |
| Power Strike 8 | 65 | 18 |
| Power Strike 9 | 70 | 19 |
| Mortal Blow 1 | 73 | 9 |
| Mortal Blow 2 | 80 | 9 |
| Mortal Blow 3 | 88 | 10 |
| Mortal Blow 4 | 115 | 11 |
| Mortal Blow 5 | 126 | 12 |
| Mortal Blow 6 | 137 | 13 |
| Mortal Blow 7 | 178 | 16 |
| Mortal Blow 8 | 193 | 16 |
| Mortal Blow 9 | 210 | 17 |
| Power Shot 1 | 65 | 19 |
| Power Shot 2 | 71 | 20 |
| Power Shot 3 | 78 | 21 |
| Power Shot 4 | 102 | 25 |
| Power Shot 5 | 112 | 26 |
| Power Shot 6 | 122 | 27 |
| Power Shot 7 | 158 | 34 |
| Power Shot 8 | 172 | 36 |
| Power Shot 9 | 187 | 37 |
| Iron Punch 1 | 29 | 11 |
| Iron Punch 2 | 31 | 12 |
| Iron Punch 3 | 34 | 13 |
| Iron Punch 4 | 45 | 15 |
| Iron Punch 5 | 49 | 15 |
| Iron Punch 6 | 54 | 16 |
| Iron Punch 7 | 69 | 20 |
| Iron Punch 8 | 76 | 21 |
| Iron Punch 9 | 82 | 22 |
| Wind Strike 1 | 12 | 9 |
| Wind Strike 2 | 13 | 9 |
| Wind Strike 3 | 15 | 10 |
| Wind Strike 4 | 18 | 14 |
| Wind Strike 5 | 21 | 15 |
| Ice Bolt 1 | 8 | 9 |
| Ice Bolt 2 | 9 | 10 |
| Ice Bolt 3 | 11 | 14 |
| Ice Bolt 4 | 13 | 15 |
| Vampiric Touch 1 | 18 | 25 |
| Vampiric Touch 2 | 21 | 28 |
| Chill Flame 1 | 20 | 15 |
| Chill Flame 2 | 30 | 23 |

What a mastery does, by level, with every multiplier applied before every addition:

| Mastery | Path | By level |
|---|---|---|
| Weapon Mastery | Fighter | P.Atk ×1.085, then +2, +3, +4 |
| Weapon Mastery | Mystic | P.Atk ×1.45 and M.Atk ×1.17, then P.Atk +1.5, +2.8 and M.Atk +1.9, +3.5 |
| Armor Mastery | Fighter | P.Def +9, +11, +12, +13, +14, and Evasion +3 at 4 and 5 in light armour |
| Armor Mastery | Mystic | P.Def +6.7, +8.0, +9.2 |
| Anti Magic | Mystic | M.Def +10, +12, +14, +16 |
| Robe Mastery | Mystic | P.Def +11.6, +13.4, +16.1, +18.4 in a robe |

Example: a level 5 Human Fighter with 260 SP learns Power Strike 2 and 3 for 50 each and Weapon
Mastery 1 for 160, with 260 − 50 − 50 − 160 = **0** left. Its Squire's Sword's P.Atk, 6 × 1.20 ×
0.94 = 6.77, becomes 6.77 × 1.085 + 2 = **9.34**, and its Power Strike strikes at power **30**.
