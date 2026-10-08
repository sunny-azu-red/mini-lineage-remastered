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

Example: a level 1 Human Fighter rests 1.55 × 0.90 × 1.58 × 3 = **6.6 HP** a tick, so its 126 HP
fill in about a minute. At level 40 it rests 33 HP a tick and fills 1,007 HP in about a minute and a
half.

## 12. Levels

A character starts at level 1 with 0 EXP and reaches each level at the EXP below. Level 80 is the
last. Reaching a level refills HP and MP.

| Levels | EXP |
|---|---|
| 1–10 | 0, 1, 2, 4, 10, 21, 38, 65, 105, 161 |
| 11–20 | 238, 339, 471, 639, 848, 1107, 1421, 1800, 2252, 2787 |
| 21–30 | 3413, 4142, 4986, 5955, 7063, 8324, 9751, 11360, 13166, 15186 |
| 31–40 | 17438, 19939, 22709, 25767, 29135, 32834, 36887, 41318, 46150, 51410 |
| 41–50 | 57124, 63319, 70024, 77269, 85083, 93499, 102549, 112267, 122688, 133847 |
| 51–60 | 151750, 170875, 191279, 213026, 236176, 269002, 303874, 340885, 380127, 421697 |
| 61–70 | 487691, 557478, 631213, 709056, 791172, 906579, 1028138, 1156085, 1290659, 1432109 |
| 71–80 | 1580686, 1775641, 2021064, 2321257, 2680734, 3104253, 3837587, 5037587, 6997587, 14000000 |

## 13. The base outcomes

How the stats meet each other. The fight builds on these.

- **Hit chance % = 88 + 2 × (Accuracy − Evasion)**, between 28% and 98%.
- **A critical hit** is rolled against Critical %, and doubles the damage.
- **Physical damage = 70 × P.Atk ÷ P.Def**, then ±10%, at least 1.
- **Magic damage = 91 × power × √M.Atk ÷ M.Def**, at least 1. A magic critical is ×4.

Example: Accuracy 40 against Evasion 34 hits **100% → 98%**. P.Atk 100 against P.Def 70 deals
**100** before the ±10%, and **200** on a critical. A spell of power 10 with M.Atk 100 against M.Def 91
deals **100**, and **400** on a magic critical.
