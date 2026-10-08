# Lineage II canon

Every Lineage II name and number in the player system, with the file it was read from. The
reference is **L2J Mobius CT_0 Interlude**, datapack and Java, used whole. The base stats come from
it, so the formulas and constants do too: mixing sources would leave numbers balanced against
formulas they were never balanced against.

`docs/lineage_2_interlude_server_formulas.md` explains the mechanics well. Where it disagrees with
the code below, the code wins (see [Where the formulas doc differs](#where-the-formulas-doc-differs)).

Paths are relative to `https://gitlab.com/MobiusDevelopment/L2J_Mobius/-/raw/master/L2J_Mobius_CT_0_Interlude/`:
`dist/game/data/…` is `D/`, and `java/org/l2jmobius/gameserver/…` is `J/`.

## Starting classes

`D/stats/players/templates/StartingClass/*.xml`.

| Class (id) | STR | CON | DEX | INT | WIT | MEN | HP L1 | MP L1 |
|---|---|---|---|---|---|---|---|---|
| Human Fighter (0) | 40 | 43 | 30 | 21 | 11 | 25 | 80 | 30 |
| Human Mystic (10) | 22 | 27 | 21 | 41 | 20 | 39 | 101 | 40 |
| Elven Fighter (18) | 36 | 36 | 35 | 23 | 14 | 26 | 89 | 30 |
| Elven Mystic (25) | 21 | 25 | 24 | 37 | 23 | 40 | 104 | 40 |
| Dark Fighter (31) | 41 | 32 | 34 | 25 | 12 | 26 | 94 | 30 |
| Dark Mystic (38) | 23 | 24 | 23 | 44 | 19 | 37 | 106 | 40 |
| Orc Fighter (44) | 40 | 47 | 26 | 18 | 12 | 27 | 80 | 30 |
| Orc Mystic (49) | 27 | 31 | 24 | 31 | 15 | 42 | 95 | 40 |

Combat bases, the same for every class of an archetype:

| | P.Atk | M.Atk | P.Def (naked slots) | M.Def (naked slots) | Critical | P.Atk.Spd | M.Atk.Spd |
|---|---|---|---|---|---|---|---|
| Fighter | 4 | 6 | 80: chest 31, legs 18, head 12, gloves 8, feet 7, underwear 3, cloak 1 | 41: earrings 9 + 9, rings 5 + 5, necklace 13 | 4 | 300 | 333 |
| Mystic | 3 | 6 | 54: chest 15, legs 8, rest as Fighter | 41 | 4 | 300 | 333 |

M.Atk.Spd 333 is `CreatureTemplate`'s default, since no template sets it. Magic critical starts at 1,
because `getMCriticalHit` passes 1 into its chain and never reads the template's `baseMCritRate`.

Initial equipment (`D/stats/players/initialEquipment.xml`), kept for the gear stage:
- **Human, Elven and Dark Fighter:** Squire's Sword (2369), Squire's Shirt (1146), Squire's Pants (1147)
- **Orc Fighter:** Training Gloves (2368), Squire's Shirt, Squire's Pants
- **Human, Elven and Dark Mystic:** Apprentice's Wand (6), Apprentice's Tunic (425), Apprentice's Stockings (461)
- **Orc Mystic:** Training Gloves, Apprentice's Tunic, Apprentice's Stockings

## Classes and their HP and MP

- Every class has its own 80-level `lvlUpgainData` table: `D/stats/players/templates/{StartingClass,1stClass,2ndClass}/*.xml`.
- A transferred class's table matches its parent's through the transfer level (20 or 40) and parts
  from the next.
- Every segment is quadratic, so `Classes` stores each as its first level's gain and how much that
  gain grows. For example, a Human Fighter's HP is `80 + 11.83(l−1) + 0.13(l−1)(l−2)/2`.
- `test/fixtures/class_tables.json` holds all 53 tables, and `class_tables_test.exs` holds `Classes`
  to every row.
- The class tree is `J/entity/actor/enums/player/PlayerClass.java`, ids 0 to 52, with the Dwarves
  (53 to 57) left out.
- The 3rd class (level 76) is not in the game.

Regeneration per 3 s tick, the same table for every class:
- **HP:** 2.0 at level 1, +0.05 a level to 2.45 at 10, then 2.5 at 11, +0.1 a level to 9.4 at 80.
- **MP:** 0.9 for levels 1–10, +0.3 every ten levels, reaching 3.0 at 71–80.

## Attribute bonus

`D/stats/statBonus.xml` is each closed form below rounded to two places, for values 0 to 99. The
closed forms match the table exactly from 1 to 99.

| | Formula | 20 | 30 | 40 | 50 |
|---|---|---|---|---|---|
| STR | 1.036^(v − 34.845) | 0.59 | 0.84 | 1.20 | 1.71 |
| CON | 1.030^(v − 27.632) | 0.80 | 1.07 | 1.44 | 1.94 |
| DEX | 1.009^(v − 19.360) | 1.01 | 1.10 | 1.20 | 1.32 |
| INT | 1.020^(v − 31.375) | 0.80 | 0.97 | 1.19 | 1.45 |
| WIT | 1.050^(v − 20) | 1.00 | 1.63 | 2.65 | 4.32 |
| MEN | 1.010^(v + 0.06) | 1.22 | 1.35 | 1.49 | 1.65 |

The level modifier is `(level + 89) / 100` (`J/entity/actor/Creature.java`, `getLevelMod`).

## Derived stats

| Stat | Formula | Source |
|---|---|---|
| P.Atk | base × STR × level | `FuncPAtkMod` |
| M.Atk | base × INT² × level² | `FuncMAtkMod` |
| P.Def | (naked slots − equipped slots + armour) × level | `FuncPDefMod` |
| M.Def | (naked slots − equipped slots + jewellery) × MEN × level | `FuncMDefMod` |
| Max HP / MP | table(class, level) × CON / MEN, truncated | `FuncMaxHpMul`, `FuncMaxMpMul`, `getMaxHp` |
| Accuracy | √DEX × 6 + level, + (level − 69) above 69, + (level − 76) above 77, rounded | `FuncAtkAccuracy` |
| Evasion | √DEX × 6 + level, + (level − 69) from 70 (× 1.2 from 78), rounded, at most 250 | `FuncAtkEvasion` |
| Critical | base × DEX × 10, at most 500, rounded; out of 1000 | `FuncAtkCritical`, `getCriticalHit` |
| Magic Critical | trunc(1 × WIT) × 10, at most 200; WIT only with a weapon | `FuncMAtkCritical`, `getMCriticalHit` |
| Atk. Spd. | 300 × DEX, at most 1500 | `MaxPAtkSpeed` |
| Casting Spd. | 333 × WIT, at most 1999 | `MaxMAtkSpeed` |
| HP / MP regen | max(1, table(level) × level × CON / MEN) × posture | `Formulas.calcHpRegen` |

- **Posture:** sitting ×1.5, standing still ×1.1, running ×0.7.
- **Regeneration period:** `HP_REGENERATE_PERIOD` is 3000 ms.
- **Caps:** from `D/../config/Player.ini`: MaxPCritRate 500, MaxMCritRate 200, MaxPAtkSpeed 1500,
  MaxMAtkSpeed 1999, MaxEvasion 250.

## Combat

All in `J/mechanics/stats/Formulas.java`.

- **Hit** (`calcHitMiss`): `(80 + 2 × (accuracy − evasion)) × 10`, × `(100 + position) / 100`,
  clamped to 200–980 out of 1000.
  - Position comes from `D/stats/hitConditionBonus.xml`: behind +10, side +5, front 0.
  - Height (±3) and night (−10) are in that file too, but the game has neither.
- **Critical** (`calcCrit`): lands when the rate beats `Rnd(1000)`. No positional modifier applies
  to an auto-attack without a skill that grants one.
- **Physical damage** (`calcPhysDam`): `76 × (P.Atk × soulshot + power) × position ÷ P.Def`.
  - Position: behind ×1.2, side ×1.1, front ×1.0.
  - A critical is ×2.
  - The random spread is ±`RANDOM_DAMAGE`% with a weapon, ±(5 + √level)% bare-handed (`getRandomDamageMultiplier`).
  - Damage is floored at 1.
  - With `RandomizeAutoAttackDamage` on, the source multiplies the spread in twice. That is a bug
    and is not copied.
- **Magic damage** (`calcMagicDam`): `91 × √M.Atk ÷ M.Def × power`.
  - A magic critical is ×3 against a monster (×2.5 between players).
  - Spiritshot doubles M.Atk; blessed spiritshot quadruples it.
- **Magic success** (`calcMagicSuccess`): `100 − round(1.3^(target level − caster level))` percent.
  On a failure the damage halves within 9 levels, and is resisted outright beyond that.
- **Effect landing** (`calcEffectSuccess`):
  `((magic level − target level + 3) × level bonus rate + activate rate + 30 − target's saving attribute)`
  × `11 × √M.Atk ÷ M.Def` for a magic skill, clamped to the skill's own min and max chance.
- **EXP** (`J/entity/actor/Attackable.java`): a monster pays its EXP in proportion to the damage
  dealt, only while the level gap is under 11 (`MonsterExpMaxLevelDifference`).
  - Overhit adds the excess damage's share of the monster's max HP, up to 25%.
- **The EXP table** is `D/stats/players/experience.xml`: 68 to reach level 2, 48,229 for level 10,
  835,854 for 20, 15,422,851 for 40, 4,200,000,000 for 80.
  - The game divides it by `Constants.exp_divisor` (300) and rounds up. At 363, levels 2 and 3
    would share a threshold.

## Dyes

- **The dyes:** `D/stats/hennaList.xml`, 180 of them, with their names and dye prices from
  `D/stats/items/04400-04699.xml`. They are kept in `priv/data/dyes.json` for the four races' classes.
- **Drawing one** takes 10 of the dye and the fee. Washing one away costs the cancel fee; the five
  dyes Interlude returns have nowhere to go without a bag.
- **Slots** (`Player.getHennaEmptySlots`): two after the first transfer, three after the second.
- **The cap** (`Player.recalcHennaStats`): each attribute takes at most +5 from dyes. A penalty is
  never capped.

## Where the formulas doc differs

| | Formulas doc | L2J, which the game follows |
|---|---|---|
| Hit chance | 88 + 2Δ, clamped 28–98% | 80 + 2Δ, clamped 20–98% |
| Physical constant | 70 | 76 |
| Magic critical | ×4, uncapped | ×3 against monsters, capped at 20% |
| Sitting at level ≤ 40 | ×6 HP regen | no such bonus |
| Standing still | ×1.0 | ×1.1 |
| HP regen below level 11 | 1.5 + level/20 | the table: 2.0 + 0.05 a level |
| EXP level penalty | 0.83^(gap − 5) | none within 10 levels, nothing beyond |
| Saving attribute | `2 − √bonus` multiplier | the attribute subtracted from the chance |

## Cross-check against aCis

[aCis](https://gitlab.com/Tryskell/acis_public) (commit `55ff8a4`) is an Interlude-only emulator
built for retail accuracy, independent of L2J Mobius. L2JFrozen breaks ties, though it shares
Mobius's L2J ancestry.

**Confirmed exactly by aCis:**
- the eight starting classes' attributes, and the combat bases
- every HP and MP table checked, including where transfers split at 21 and 41
- the attribute bonus formulas and the level modifier
- the derived P.Atk, M.Atk, P.Def, M.Def, Max HP and Max MP
- Critical
- the MP regen table and the posture multipliers
- magic damage, the random spread and the overhit cap
- the EXP table and the level 80 cap
- the dyes, slots and the +5 cap

**Where aCis differs from the game:**

| | Game (Mobius) | aCis | L2JFrozen |
|---|---|---|---|
| HP regen table | 2.0 +0.05/level to 10, then 2.5 +0.1/level | 2.0 for 1–10, 2.5, 3.5, then +1 every 10 levels to 8.5 | a third model |
| Physical constant | 76 | 77 | 70 |
| Side position | ×1.1 | ×1.05 (on a critical: behind ×1.1, side ×1.025) | — |
| Hit chance | (80 + 2Δ)×10, ×position, 200–980 | (90 + 2Δ)×10, position added to Δ, 300–980 | as the game |
| Magic critical damage | ×3 | ×4 | ×3 |
| Magic critical rate | trunc(WIT)×10, cap 200 | 8 × WIT, no cap | cap 300 |
| Magic success | fail 1.3^gap | fail 1.166^gap | 1.3^gap |
| EXP level gap | none at a gap of 11 or more | ×(5/6)^(gap−5) once the player is more than 5 above | as aCis |
| Accuracy/Evasion past 69, Evasion cap 250 | yes | none | different extras, no cap |
| Speed caps 1500/1999 | yes | none | config defaults |
| Naked P.Def | underwear and cloak deducted | not deducted | — |
| Attack delay | 470000/P.Atk.Spd ms | 500000/P.Atk.Spd ms | — |
