# Skills

Part of the Lineage II canon (Interlude, C6): the reference the game takes names and numbers from.
It is not a roadmap. Read [README.md](README.md) before using an entry.

Each base set's skills up to level 20, the numbers of the attack skills the first hunt uses, and
how the servers resolve them. The two datapacks checked (aCis 409 and L2J C6) agree on every skill
tree row; where their combat code differs, both values are given.

## The first skills' numbers

Confirmed in aCis 409 and L2J C6 (skill XML), with l2hub.info for the MP totals. MP is the total
spent, the initial part plus the part on completion. Hit time is the cast or swing plus its
recovery, before Atk. Spd. or Casting Spd. scale it.

| Skill | Id | Kind | Power by level | MP at level 1 | Hit time (ms) | Reuse (ms) |
|---|---|---|---|---|---|---|
| Power Strike | 3 | physical, sword or blunt | 25, 27, 30, 39, 42, 46, 60, 65, 70 | 10 | 1080 + 720 | 13000 |
| Mortal Blow | 16 | blow, dagger | 73, 80, 88, 115, 126, 137, 178, 193, 210 | 9 | 1080 + 720 | 11000 |
| Power Shot | 56 | physical, bow | 65, 71, 78, 102, 112, 122, 158, 172, 187 | 19 | 3200 + 800 | 25000 |
| Iron Punch | 29 | physical, fists | 29, 31, 34, 45, 49, 54, 69, 76, 82 | 11 | 1604 + 296 | 15000 |
| Wind Strike | 1177 | magic, wind | 12, 13, 15, 18, 21 | 9 | 4000 | 6000 |
| Ice Bolt | 1184 | magic, water; Run Spd −30% for 120s | 8, 9, 11, 13 | 9 | 3100 + 200 | 8000 |
| Vampiric Touch | 1147 | magic drain, dark; heals 40% of the damage | 18, 21, 23, 26, 29, 32 | 25 | 4000 | 12000 |
| Chill Flame | 1100 | damage over time, fire | 20 or 30 HP a second, 15 ticks | 15 | 4000 | 6000 |
| Soul Cry | 1001 | toggle, P.Atk +4.5 / +14 | | 2, then a drain | | |

Where each is learned in Lineage II: Wind Strike (Human, Elven and Dark Mystic) and Soul Cry (Orc
Mystic) at level 1, free; Power Strike, Mortal Blow, Power Shot (Human, Elven and Dark Fighter) and
Iron Punch (Orc Fighter) at 5; Ice Bolt at 7, with a spellbook; Chill Flame (Orc Mystic) at 7, with
an amulet; Vampiric Touch (Human and Dark Mystic only) at 14.

## Skills

- **Vampiric Touch (1147)**: Active magic DRAIN, dark element, single target, cast range 600. 6 levels. Power 18/21/23/26/29/32; MP initial 5/6/7/7/8/8 plus 20/22/25/28/30/32 on completion (total 25/28/32/35/38/40; l2hub shows lvl1 MP 25). Hit (cast) time 4000 ms, no cool time, reuse 12000 ms. absorbPart 0.4: caster heals 40% of the HP damage actually dealt (damage is the normal magic formula). Skill magic levels 11/14/17/20/23/25. Learned in the base 1-20 tree only by Human Mystic and Dark Mystic: levels 1 and 2 at character level 14 for 1,100 SP each. Elven Mystic and Orc Mystic do not get it (Orc Mystic has Life Drain 1090 instead; Dark Fighter has Drain Health 70). Sources: [github:DEVjEXTREME/L2jaCis-409](https://github.com/DEVjEXTREME/L2jaCis-409/blob/master/aCis_datapack/data/xml/skills/1100-1199.xml), [github:Hl4p3x/L2JServer_C6_Interlude](https://github.com/Hl4p3x/L2JServer_C6_Interlude/blob/master/dist/game/data/stats/skills/1100-1199.xml), [github:DEVjEXTREME/L2jaCis-409](https://github.com/DEVjEXTREME/L2jaCis-409/blob/master/aCis_datapack/data/xml/classes/humanMystic.xml), [github:DEVjEXTREME/L2jaCis-409](https://github.com/DEVjEXTREME/L2jaCis-409/blob/master/aCis_datapack/data/xml/classes/darkMystic.xml), [github:Hl4p3x/L2JServer_C6_Interlude](https://github.com/Hl4p3x/L2JServer_C6_Interlude/blob/master/dist/db_installer/sql/install/skill_trees.sql), [l2hub.info](https://l2hub.info/il/skills/1147).
- **Shadow Sense (294)**: Passive, 1 level. Adds +3 to Accuracy (stat accCombat, flat add) only while it is night in game time. aCis writes the condition as <game night="true"/>, L2J C6 as <cond><game time="night"/></cond>; l2hub lists it as 'Hit at night +3' (p_hit_at_night). Dark Fighter learns it at level 15 for 2,900 SP (both packs). Counterweight: both cores give every attacker a night penalty to normal-attack hit chance (see the hit/miss mechanic), so +3 Accuracy roughly offsets it for Dark Elves. Sources: [github:DEVjEXTREME/L2jaCis-409](https://github.com/DEVjEXTREME/L2jaCis-409/blob/master/aCis_datapack/data/xml/skills/0200-0299.xml), [github:Hl4p3x/L2JServer_C6_Interlude](https://github.com/Hl4p3x/L2JServer_C6_Interlude/blob/master/dist/game/data/stats/skills/0200-0299.xml), [github:Hl4p3x/L2JServer_C6_Interlude](https://github.com/Hl4p3x/L2JServer_C6_Interlude/blob/master/dist/db_installer/sql/install/skill_trees.sql), [l2hub.info](https://l2hub.info/il/skills/294).

## How the servers resolve them

- **Weapon conditions (Power Strike 3, Mortal Blow 16, Iron Punch 29, Power Shot 56)**: Both packs gate them with `weaponsAllowed` rather than a `<cond>`: aCis writes Power Strike `SWORD,BLUNT,BIGBLUNT,BIGSWORD`, Mortal Blow `DAGGER`, Iron Punch `DUALFIST`, Power Shot `BOW`; L2J writes the same as bitmasks of `1 << WeaponType id` (18444, 16, 1024, 32). So Power Strike takes a one- or two-handed sword or blunt (a staff is a BIGBLUNT) but no pole, dual sword, dagger, bow or fist weapon. A spellbook or horn (Apprentice's Spellbook, Buffalo's Horn, Relic of The Saints) is `ETC` and fits none. Iron Punch cannot be used bare-handed: an empty hand is a FIST template, not DUALFIST. With the wrong weapon the cast is refused before any MP is spent (aCis `CreatureCast.canCast`, L2J `PlayerInstance.useMagic`) and the server sends system message 113, "$s1 cannot be used due to unsuitable terms." No server packet greys the skill over its weapon: SkillList's disabled byte is only formal wear or a clan skill under negative reputation in aCis, always 0 in L2J; whether the client dims it on its own is unverified. The learn window carries no weapon either; only the skill's description names it (L2J's XML comments: Power Strike "Used when equipped with a sword or blunt weapon.", Mortal Blow "An equipped dagger weapon is required to use this skill.", Iron Punch "An equipped fist weapon is required to use this skill."). No first-tier mystic skill, aura, heal, Drain Health, Soul Cry or Relax has a weapon condition. Sources: [github:DEVjEXTREME/L2jaCis-409](https://github.com/DEVjEXTREME/L2jaCis-409/blob/main/aCis_datapack/data/xml/skills/0000-0099.xml), [github:Hl4p3x/L2JServer_C6_Interlude](https://github.com/Hl4p3x/L2JServer_C6_Interlude/blob/master/dist/game/data/stats/skills/0000-0099.xml), [github:DEVjEXTREME/L2jaCis-409](https://github.com/DEVjEXTREME/L2jaCis-409/blob/main/aCis_gameserver/java/net/sf/l2j/gameserver/model/actor/cast/CreatureCast.java), [github:Hl4p3x/L2JServer_C6_Interlude](https://github.com/Hl4p3x/L2JServer_C6_Interlude/blob/master/java/org/l2jserver/gameserver/model/actor/instance/PlayerInstance.java).
- **Blow resolution (Mortal Blow 16)**: aCis (Formulas.calcBlowRate): blowRate/1000 = baseLandRate x 2 x DEX_BONUS[DEX] x BLOW_RATE stat x posMul, where Mortal Blow baseLandRate = 200, posMul = 1.15 behind, 1.1 side, 1.0 front, capped at 800/1000 (Backstab: 1000, and only 3% from the front). DEX_BONUS[d] = round2(1.009^(d - 19.36)): DEX 30 -> 1.10, DEX 34 -> 1.14, DEX 35 -> 1.15. So Dark Fighter (DEX 34) lands Mortal Blow 45.6% front / 50.2% side / 52.4% behind. A miss does nothing (no damage, MP still spent). Then P_SKILL_EVASION (0 unless the target has a dodge skill) can dodge it. aCis damage (calcBlowDamage) = ((P.Atk x (2 if soulshot) + power x (SSBoost if soulshot)) x critDmgMul(1) x rnd(0.95-1.05) x critPosMul x posMul(behind 1.1, side 1.025, front 1) x pvpMul x critVuln x daggerVuln + critAdd x 6) x 77 / P.Def (70 in PvP); a shield block adds shield def, a perfect block returns 1. Mortal Blow has no baseCritRate, so the extra x2 skill-crit never fires. L2J C6 (Blow.java + Formulas.calcBlow): chance% = Config BlowAttackFront 50 / Side 60 / Behind 70, times (1 + (DEX - 20) / 100) computed in INTEGER arithmetic (so DEX has no effect below 120), times BLOW_RATE stat; only rolled because Mortal Blow has condition COND_CRIT (16). L2J damage = (P.Atk x (2 if soulshot and dagger) + power) x 70 / P.Def x weapon random (±weapon randomDamage%, or ±(5 + sqrt(level))% bare), then CRITICAL_DAMAGE stat, dagger vulnerability, and extra divisors vs heavy/light/robe-wearing players. Sources: [github:DEVjEXTREME/L2jaCis-409](https://github.com/DEVjEXTREME/L2jaCis-409/blob/master/aCis_gameserver/java/net/sf/l2j/gameserver/skills/Formulas.java), [github:DEVjEXTREME/L2jaCis-409](https://github.com/DEVjEXTREME/L2jaCis-409/blob/master/aCis_gameserver/java/net/sf/l2j/gameserver/handler/skillhandlers/Blow.java), [github:Hl4p3x/L2JServer_C6_Interlude](https://github.com/Hl4p3x/L2JServer_C6_Interlude/blob/master/java/org/l2jserver/gameserver/model/skills/Formulas.java), [github:Hl4p3x/L2JServer_C6_Interlude](https://github.com/Hl4p3x/L2JServer_C6_Interlude/blob/master/java/org/l2jserver/gameserver/handler/skillhandlers/Blow.java), [github:Hl4p3x/L2JServer_C6_Interlude](https://github.com/Hl4p3x/L2JServer_C6_Interlude/blob/master/dist/game/config/main/Physics.ini).
- **DoT tick (Chill Flame 1100, poisons)**: Fixed damage per tick, NOT scaled by M.Atk in either core: EffectDamOverTime.onActionTime subtracts the effect's val directly (aCis getTemplate().getValue(); L2J calc() of a constant lambda). Chill Flame = 20 (lvl1) / 30 (lvl2) HP per tick, count 15. Tick period = the effect's time attribute in seconds: L2J sets time="1"; aCis omits it and DocumentBase defaults time to 1. So 1 tick per second, 15 s, 300 / 450 HP total. Poisons (Curse: Poison 1168, Venom 1095) use time=3, count=10: 24 HP every 3 s for 30 s at lvl1. A DoT will not kill: if a tick would reach 0 it leaves 1 HP (aCis unless the skill is flagged killByDOT; L2J for all but skill 4082). Landing is a separate debuff roll (calcSkillSuccess) using the skill's power 70 as land rate vs the target, with lvlDepend; L2J also lists saveVs MEN. Sources: [github:DEVjEXTREME/L2jaCis-409](https://github.com/DEVjEXTREME/L2jaCis-409/blob/master/aCis_gameserver/java/net/sf/l2j/gameserver/skills/effects/EffectDamOverTime.java), [github:DEVjEXTREME/L2jaCis-409](https://github.com/DEVjEXTREME/L2jaCis-409/blob/master/aCis_gameserver/java/net/sf/l2j/gameserver/data/DocumentBase.java), [github:Hl4p3x/L2JServer_C6_Interlude](https://github.com/Hl4p3x/L2JServer_C6_Interlude/blob/master/java/org/l2jserver/gameserver/model/skills/effects/EffectDamOverTime.java), [github:DEVjEXTREME/L2jaCis-409](https://github.com/DEVjEXTREME/L2jaCis-409/blob/master/aCis_datapack/data/xml/skills/1100-1199.xml), [github:Hl4p3x/L2JServer_C6_Interlude](https://github.com/Hl4p3x/L2JServer_C6_Interlude/blob/master/dist/game/data/stats/skills/1100-1199.xml).
- **Drain skills (Vampiric Touch, Drain Health, Life Drain)**: Damage is ordinary magic damage, calcMagicDam (91 x sqrt(M.Atk x shot mult) / M.Def x power, magic crit and fail rules apply). Absorb: drain = damage, capped at the target's current HP; vs a player with CP, only damage beyond current CP counts. Caster heals absorbAbs + absorbPart x drain (absorbAbs 0 for these). absorbPart: Vampiric Touch 0.4, Drain Health 0.2, Life Drain 0.8. Same code shape in aCis L2SkillDrain.useSkill and L2J SkillDrain.useSkill (L2J clamps to max HP explicitly). A half-failed magic roll halves damage with the message 'Drain was only 50 percent successful'. Sources: [github:DEVjEXTREME/L2jaCis-409](https://github.com/DEVjEXTREME/L2jaCis-409/blob/master/aCis_gameserver/java/net/sf/l2j/gameserver/skills/l2skills/L2SkillDrain.java), [github:Hl4p3x/L2JServer_C6_Interlude](https://github.com/Hl4p3x/L2JServer_C6_Interlude/blob/master/java/org/l2jserver/gameserver/model/skills/handlers/SkillDrain.java), [github:DEVjEXTREME/L2jaCis-409](https://github.com/DEVjEXTREME/L2jaCis-409/blob/master/aCis_gameserver/java/net/sf/l2j/gameserver/skills/Formulas.java), [github:Hl4p3x/L2JServer_C6_Interlude](https://github.com/Hl4p3x/L2JServer_C6_Interlude/blob/master/java/org/l2jserver/gameserver/model/skills/Formulas.java).
- **Physical skill damage (Power Strike, Power Shot, Iron Punch)**: aCis calcPhysicalSkillDamage: damage = (P.Atk x ssMul + power x (SSBoost if shot)) x rnd x raceMul x pvpMul x elemMul x weaponVuln x 77 / P.Def, ssMul = 2.04 with a soulshot (else 1), SSBoost 2.0 on these three, rnd = 1 ± weapon randomDamage% (bare hands ±(5 + floor(sqrt(level)))%); x2 if the skill crits (only skills with baseCritRate > 0, chance baseCritRate x 10 x STR bonus /1000); minimum 1. L2J calcPhysDam (shared with normal attacks): damage = (P.Atk x (2 if shot) + power x (SSBoost if shot)) x 70 / P.Def, then weapon-type vulnerability, then + up to 10% (damage += rand[0,1) x damage / 10), then race bonuses (P.Atk vs undead/beasts...). Disagreement: constant 77 (aCis) vs 70 (L2J); soulshot P.Atk 2.04 vs 2; random ±weapon% vs +0-10%. Sources: [github:DEVjEXTREME/L2jaCis-409](https://github.com/DEVjEXTREME/L2jaCis-409/blob/master/aCis_gameserver/java/net/sf/l2j/gameserver/skills/Formulas.java), [github:Hl4p3x/L2JServer_C6_Interlude](https://github.com/Hl4p3x/L2JServer_C6_Interlude/blob/master/java/org/l2jserver/gameserver/model/skills/Formulas.java), [github:DEVjEXTREME/L2jaCis-409](https://github.com/DEVjEXTREME/L2jaCis-409/blob/master/aCis_gameserver/java/net/sf/l2j/gameserver/handler/skillhandlers/Pdam.java), [github:Hl4p3x/L2JServer_C6_Interlude](https://github.com/Hl4p3x/L2JServer_C6_Interlude/blob/master/java/org/l2jserver/gameserver/handler/skillhandlers/Pdam.java).
- **Magic skill damage (Wind Strike, Ice Bolt)**: Both: damage = 91 x sqrt(M.Atk x shotMul) / M.Def x power, shotMul 2 spiritshot, 4 blessed spiritshot. Magic crit: aCis x4, L2J x Config MagicCriticalPower = 3.0. aCis also applies elemental modifier; L2J skill vulnerability. Sources: [github:DEVjEXTREME/L2jaCis-409](https://github.com/DEVjEXTREME/L2jaCis-409/blob/master/aCis_gameserver/java/net/sf/l2j/gameserver/skills/Formulas.java), [github:Hl4p3x/L2JServer_C6_Interlude](https://github.com/Hl4p3x/L2JServer_C6_Interlude/blob/master/java/org/l2jserver/gameserver/model/skills/Formulas.java), [github:Hl4p3x/L2JServer_C6_Interlude](https://github.com/Hl4p3x/L2JServer_C6_Interlude/blob/master/dist/game/config/main/Physics.ini).
- **Normal attack duration from Atk. Spd, and the bow delay**: aCis: Formulas.calculateTimeBetweenAttacks = max(100, 500000 / PAtkSpd) ms; the hit lands at half that for melee (sword etc.), the swing ends at the full time. Bow: the hit lands at the full 500000/PAtkSpd, then a bow cool-down of weaponReuseDelay x 345 / PAtkSpd ms (CreatureAttack.doAttackHitByBow; the gauge shows the sum). L2J C6: Creature.calculateTimeBetweenAttacks -> Formulas.calcPAtkSpd = 470000 / PAtkSpd ms (2700 if rate < 2), hit at half; Bow: 1500 x 345 / PAtkSpd = 517500 / PAtkSpd to hit, plus calculateReuseTime = weaponReuse x 345 / PAtkSpd (non-bow weapons with a reuse use x312). Disagreement: 500000 (aCis) vs 470000 (L2J) for melee. Example PAtkSpd 300: aCis 1667 ms, L2J 1567 ms per swing. Sources: [github:DEVjEXTREME/L2jaCis-409](https://github.com/DEVjEXTREME/L2jaCis-409/blob/master/aCis_gameserver/java/net/sf/l2j/gameserver/skills/Formulas.java), [github:DEVjEXTREME/L2jaCis-409](https://github.com/DEVjEXTREME/L2jaCis-409/blob/master/aCis_gameserver/java/net/sf/l2j/gameserver/model/actor/attack/CreatureAttack.java), [github:Hl4p3x/L2JServer_C6_Interlude](https://github.com/Hl4p3x/L2JServer_C6_Interlude/blob/master/java/org/l2jserver/gameserver/model/skills/Formulas.java), [github:Hl4p3x/L2JServer_C6_Interlude](https://github.com/Hl4p3x/L2JServer_C6_Interlude/blob/master/java/org/l2jserver/gameserver/model/actor/Creature.java).
- **Cast time and reuse scaling by Casting Spd / Atk. Spd**: Both cores: hitTime and coolTime x 333 / MAtkSpd for magic skills (x 333 / PAtkSpd for physical skills). Spiritshot or blessed spiritshot on a magic skill: x0.70 more. aCis floors the result at 500 ms when the base was >= 500. Reuse: base reuse x reuse-rate stat x 333 / MAtkSpd (magic) or / PAtkSpd (physical), unless the skill is staticReuse. So at Casting Spd 333 the listed numbers apply as written; at Casting Spd 250, Wind Strike's 4000 ms becomes 5328 ms and its 6000 ms reuse 7992 ms. L2J additionally lets Skill Mastery zero the reuse. Sources: [github:DEVjEXTREME/L2jaCis-409](https://github.com/DEVjEXTREME/L2jaCis-409/blob/master/aCis_gameserver/java/net/sf/l2j/gameserver/model/actor/cast/CreatureCast.java), [github:DEVjEXTREME/L2jaCis-409](https://github.com/DEVjEXTREME/L2jaCis-409/blob/master/aCis_gameserver/java/net/sf/l2j/gameserver/skills/Formulas.java), [github:Hl4p3x/L2JServer_C6_Interlude](https://github.com/Hl4p3x/L2JServer_C6_Interlude/blob/master/java/org/l2jserver/gameserver/model/actor/Creature.java), [github:Hl4p3x/L2JServer_C6_Interlude](https://github.com/Hl4p3x/L2JServer_C6_Interlude/blob/master/java/org/l2jserver/gameserver/model/skills/Formulas.java).
- **Hit and miss: normal attacks vs skills**: Only NORMAL attacks roll Accuracy vs Evasion (calcHitMiss is called only from the auto-attack code in both cores). aCis: hit% = clamp(90 + 2 x (Accuracy - Evasion + mods), 30, 98), mods: +3 attacking from 50+ above, -3 from below, -10 at night, +10 from behind, +5 from the side. L2J: hit% = clamp((80 + 2 x (Accuracy - Evasion)) x condBonus, 20, 98), condBonus = 1 + 0.10 back + 0.05 side - 0.10 night ± 0.03 height (hitConditionBonus.xml). Physical skills (Power Strike, Mortal Blow...) never roll Accuracy; they can only be dodged by the P_SKILL_EVASION stat (0 by default; aCis exempts bows, L2J exempts skills with cast range > 40). Blows have their own land chance (above). Magic skills never miss but can fail (when MagicFailures = True, the shipped setting in both): aCis fail chance = 1% x 1.166^(targetLvl - (skillMagicLvl + lvlDepend)) when positive (1% otherwise); L2J fail chance = 1% x 1.3^(targetLvl - skillMagicLvl) (below 1% when negative); capped 99%. On a fail a second roll decides: success and target no more than 9 levels above the caster -> half damage, otherwise 1 damage ('resisted'). Debuffs and DoTs use a separate land roll (calcSkillSuccess). Sources: [github:DEVjEXTREME/L2jaCis-409](https://github.com/DEVjEXTREME/L2jaCis-409/blob/master/aCis_gameserver/java/net/sf/l2j/gameserver/skills/Formulas.java), [github:Hl4p3x/L2JServer_C6_Interlude](https://github.com/Hl4p3x/L2JServer_C6_Interlude/blob/master/java/org/l2jserver/gameserver/model/skills/Formulas.java), [github:Hl4p3x/L2JServer_C6_Interlude](https://github.com/Hl4p3x/L2JServer_C6_Interlude/blob/master/dist/game/data/stats/hitConditionBonus.xml), [github:DEVjEXTREME/L2jaCis-409](https://github.com/DEVjEXTREME/L2jaCis-409/blob/master/aCis_gameserver/java/net/sf/l2j/gameserver/model/actor/attack/CreatureAttack.java).

## Rewards

- **EXP/SP level-difference penalty on kills**: diff = killer level - monster level (party: highest member level - monster level). Base share = monster EXP (and SP) x damage dealt / total damage (L2J: / max HP, damage capped at max HP). If diff > 5: EXP and SP x (5/6)^(diff - 5). If diff <= 5 nothing changes, and there is NO bonus for killing a higher-level monster (L2J clamps diff at -5 only for the optional exponent mode). Examples: 6 levels over x0.833, 8 over x0.579, 10 over x0.402, 15 over x0.162, 20 over x0.065. EXP rounded down; if EXP comes to 0, SP is 0 too. Identical in aCis Monster.calculateExpAndSp and L2J Attackable.calculateExpAndSp (L2J's AltGameExponentXp/Sp alternative is 0 = off in the shipped config). Separately, an over-hit adds up to +25% EXP, and a summoned servitor takes its EXP penalty share. Related drops rule (aCis DEEPBLUE_DROP_RULES): drop chance x max(0.1, 1 - 0.18 x (highestAttackerLvl - mobLvl - 5)) for regular monsters (-2 for raids). Sources: [github:DEVjEXTREME/L2jaCis-409](https://github.com/DEVjEXTREME/L2jaCis-409/blob/master/aCis_gameserver/java/net/sf/l2j/gameserver/model/actor/instance/Monster.java), [github:Hl4p3x/L2JServer_C6_Interlude](https://github.com/Hl4p3x/L2JServer_C6_Interlude/blob/master/java/org/l2jserver/gameserver/model/actor/Attackable.java), [github:Hl4p3x/L2JServer_C6_Interlude](https://github.com/Hl4p3x/L2JServer_C6_Interlude/blob/master/dist/game/config/main/Character.ini).

## Each base set's skills, levels 1 to 20

### Human Fighter

| Skill | Id | Learned at | SP per skill level | What it does |
|---|---|---|---|---|
| Lucky | 194 | 1 (level 1) | 0 | passive Lucky (skill type LUCK): no EXP lost on death at low level (handled in core, not by a stat) |
| Create Common Item | 1320 | 1 (level 1), 20 (level 2) | 0, 0 | Create Common Item (dwarf-style common craft levels), free; crafting, not combat |
| Common Craft | 1322 | 1 (level 1) | 0 | Common Craft, free; crafting, not combat |
| Power Strike | 3 | 5 (levels 1–3), 10 (levels 4–6), 15 (levels 7–9) | 50, 370, 1300 | active melee physical attack (sword/blunt only); power 25,27,30 / 39,42,46 / 60,65,70; MP 10-19; 1080+720 ms; reuse 13 s; soulshot boosts skill power x2 |
| Mortal Blow | 16 | 5 (levels 1–3), 10 (levels 4–6), 15 (levels 7–9) | 50, 370, 1300 | active dagger-only BLOW; power 73,80,88 / 115,126,137 / 178,193,210; MP 9-17; 1080+720 ms; reuse 11 s; chance-based (see blow mechanic) |
| Power Shot | 56 | 5 (levels 1–3), 10 (levels 4–6), 15 (levels 7–9) | 50, 370, 1300 | active bow-only physical shot, range 700; power 65,71,78 / 102,112,122 / 158,172,187; MP 19-37; 3200+800 ms; reuse 25 s |
| Weapon Mastery | 141 | 5 (level 1), 10 (level 2), 15 (level 3) | 160, 1100, 4000 | passive fighter Weapon Mastery: P.Atk x1.085 then +2/+3/+4 |
| Armor Mastery | 142 | 5 (level 1), 10 (levels 2–3), 15 (levels 4–5) | 160, 550, 2000 | passive fighter Armor Mastery: P.Def +9/+11/+12/+13/+14; Evasion +3 at levels 4-5 |
| Relax | 226 | 5 (level 1) | 160 | toggle Relax: while sitting, HP regen +5; drains 2 MP per 2 s |
| Expertise S | 239 | 20 (level 1) | 0 | Expertise lvl 1 (D grade) granted free at 20: removes the grade penalty for D-grade gear |

Sources: [DEVjEXTREME/L2jaCis-409](https://github.com/DEVjEXTREME/L2jaCis-409/blob/master/aCis_datapack/data/xml/classes/humanFighter.xml), [Hl4p3x/L2JServer_C6_Interlude](https://github.com/Hl4p3x/L2JServer_C6_Interlude/blob/master/dist/db_installer/sql/install/skill_trees.sql).

### Human Mystic

| Skill | Id | Learned at | SP per skill level | What it does |
|---|---|---|---|---|
| Magician's Movement | 118 | 1 (level 1) | 0 | passive Magician's Movement: Atk. Spd x0.8 unless wearing a robe (using kind MAGIC = robe armor type) (aCis only, L2J has no row) |
| Spellcraft | 163 | 1 (level 1) | 0 | passive Spellcraft: Casting Spd x0.5 unless wearing a robe (the mystic armor penalty) |
| Lucky | 194 | 1 (level 1) | 0 | passive Lucky (skill type LUCK): no EXP lost on death at low level (handled in core, not by a stat) |
| Mana Recovery | 214 | 1 (level 1) | 0 | passive Mana Recovery: MP regen x1.2 while wearing a robe |
| Wind Strike | 1177 | 1 (level 1), 7 (levels 2–3), 14 (levels 4–5) | 0, 240, 1100 | magic attack Wind Strike; power 12 (lvl1, free at 1), 13,15 / 18,21; MP 2+7..3+12; 4000 ms; reuse 6 s |
| Self Heal | 1216 | 1 (level 1) | 0 | Self Heal (free at 1): 42 HP; MP 2+7; 5000 ms; reuse 10 s |
| Create Common Item | 1320 | 1 (level 1), 20 (level 2) | 0, 0 | Create Common Item (dwarf-style common craft levels), free; crafting, not combat |
| Common Craft | 1322 | 1 (level 1) | 0 | Common Craft, free; crafting, not combat |
| Anti Magic | 146 | 7 (levels 1–2), 14 (levels 3–4) | 240, 1100 | passive Anti Magic: M.Def +10/+12/+14/+16 |
| Armor Mastery | 244 | 7 (level 1), 14 (levels 2–3) | 470, 1100 | passive mystic Armor Mastery: P.Def +6.7/+8.0/+9.2 |
| Weapon Mastery | 249 | 7 (level 1), 14 (level 2) | 470, 2100 | passive mystic Weapon Mastery: P.Atk x1.45 then +1.5/+2.8, M.Atk x1.17 then +1.9/+3.5; bow/pole: Casting Spd x0.7, Accuracy -9 |
| Heal | 1011 | 7 (levels 1–3), 14 (levels 4–6) | 160, 700 | heal target; power 49,58,67 / 83,95,107 HP; MP 2+8..5+17; 5000 ms; reuse 10 s |
| Cure Poison | 1012 | 7 (level 1) | 470 | cure poison on target; MP 2+8; 4000 ms; reuse 15 s |
| Shield | 1040 | 7 (level 1) | 470 | target buff Shield: P.Def x1.08, 20 min; MP 2+8; 4000 ms; reuse 6 s; TARGET_ONE, so it can be cast on oneself |
| Might | 1068 | 7 (level 1) | 470 | target buff Might: P.Atk x1.08, 20 min; MP 2+8; 4000 ms; reuse 6 s |
| Curse: Poison | 1168 | 7 (level 1) | 470 | poison DoT Curse: Poison: 24 HP every 3 s x10 (30 s); land rate 70; MP 2+8; reuse 12 s |
| Ice Bolt | 1184 | 7 (levels 1–2), 14 (levels 3–4) | 240, 1100 | magic attack Ice Bolt + slow (Speed x0.7); power 8,9 / 11,13; MP 2+7..3+12; 3100+200 ms; reuse 8 s |
| Battle Heal | 1015 | 14 (levels 1–3) | 700 | fast heal target; power 83,95,107 HP; MP 5+20..7+25; 2000 ms; reuse 3 s |
| Group Heal | 1027 | 14 (levels 1–3) | 700 | party heal; power 66,76,86 HP; MP 7+26..9+34; 7000 ms; reuse 25 s |
| Vampiric Touch | 1147 | 14 (levels 1–2) | 1100 | active magic drain Vampiric Touch (dark); power 18 / 21; heals caster 40% of damage; MP 5+20 / 6+22; 4000 ms; reuse 12 s |
| Curse: Weakness | 1164 | 14 (level 1) | 2100 | debuff Curse: Weakness: target P.Atk x0.83 for 15 s; MP 1+2; 1500 ms; reuse 8 s |
| Expertise S | 239 | 20 (level 1) | 0 | Expertise lvl 1 (D grade) granted free at 20: removes the grade penalty for D-grade gear |

Sources: [DEVjEXTREME/L2jaCis-409](https://github.com/DEVjEXTREME/L2jaCis-409/blob/master/aCis_datapack/data/xml/classes/humanMystic.xml), [Hl4p3x/L2JServer_C6_Interlude](https://github.com/Hl4p3x/L2JServer_C6_Interlude/blob/master/dist/db_installer/sql/install/skill_trees.sql).

### Elven Fighter

| Skill | Id | Learned at | SP per skill level | What it does |
|---|---|---|---|---|
| Lucky | 194 | 1 (level 1) | 0 | passive Lucky (skill type LUCK): no EXP lost on death at low level (handled in core, not by a stat) |
| Create Common Item | 1320 | 1 (level 1), 20 (level 2) | 0, 0 | Create Common Item (dwarf-style common craft levels), free; crafting, not combat |
| Common Craft | 1322 | 1 (level 1) | 0 | Common Craft, free; crafting, not combat |
| Power Strike | 3 | 5 (levels 1–3), 10 (levels 4–6), 15 (levels 7–9) | 50, 310, 1100 | active melee physical attack (sword/blunt only); power 25,27,30 / 39,42,46 / 60,65,70; MP 10-19; 1080+720 ms; reuse 13 s; soulshot boosts skill power x2 |
| Mortal Blow | 16 | 5 (levels 1–3), 10 (levels 4–6), 15 (levels 7–9) | 50, 310, 1100 | active dagger-only BLOW; power 73,80,88 / 115,126,137 / 178,193,210; MP 9-17; 1080+720 ms; reuse 11 s; chance-based (see blow mechanic) |
| Power Shot | 56 | 5 (levels 1–3), 10 (levels 4–6), 15 (levels 7–9) | 50, 310, 1100 | active bow-only physical shot, range 700; power 65,71,78 / 102,112,122 / 158,172,187; MP 19-37; 3200+800 ms; reuse 25 s |
| Defense Aura | 91 | 5 (level 1) | 160 | self buff P.Def x1.08 for 20 min; MP 1+4; 4000 ms cast |
| Weapon Mastery | 141 | 5 (level 1), 10 (level 2), 15 (level 3) | 160, 910, 3300 | passive fighter Weapon Mastery: P.Atk x1.085 then +2/+3/+4 |
| Armor Mastery | 142 | 5 (level 1), 10 (levels 2–3), 15 (levels 4–5) | 160, 460, 1700 | passive fighter Armor Mastery: P.Def +9/+11/+12/+13/+14; Evasion +3 at levels 4-5 |
| Attack Aura | 77 | 10 (level 1) | 910 | self buff P.Atk x1.08 for 20 min; MP 2+5; 4000 ms cast |
| Elemental Heal | 58 | 15 (levels 1–3) | 1100 | self heal (elven fighter); power 71/75/80 HP; MP 8+32..9+36; 5000 ms; reuse 10 s |
| Expertise S | 239 | 20 (level 1) | 0 | Expertise lvl 1 (D grade) granted free at 20: removes the grade penalty for D-grade gear |

Sources: [DEVjEXTREME/L2jaCis-409](https://github.com/DEVjEXTREME/L2jaCis-409/blob/master/aCis_datapack/data/xml/classes/elvenFighter.xml), [Hl4p3x/L2JServer_C6_Interlude](https://github.com/Hl4p3x/L2JServer_C6_Interlude/blob/master/dist/db_installer/sql/install/skill_trees.sql).

### Elven Mystic

| Skill | Id | Learned at | SP per skill level | What it does |
|---|---|---|---|---|
| Magician's Movement | 118 | 1 (level 1) | 0 | passive Magician's Movement: Atk. Spd x0.8 unless wearing a robe (using kind MAGIC = robe armor type) (aCis only, L2J has no row) |
| Spellcraft | 163 | 1 (level 1) | 0 | passive Spellcraft: Casting Spd x0.5 unless wearing a robe (the mystic armor penalty) |
| Lucky | 194 | 1 (level 1) | 0 | passive Lucky (skill type LUCK): no EXP lost on death at low level (handled in core, not by a stat) |
| Mana Recovery | 214 | 1 (level 1) | 0 | passive Mana Recovery: MP regen x1.2 while wearing a robe |
| Wind Strike | 1177 | 1 (level 1), 7 (levels 2–3), 14 (levels 4–5) | 0, 260, 1100 | magic attack Wind Strike; power 12 (lvl1, free at 1), 13,15 / 18,21; MP 2+7..3+12; 4000 ms; reuse 6 s |
| Self Heal | 1216 | 1 (level 1) | 0 | Self Heal (free at 1): 42 HP; MP 2+7; 5000 ms; reuse 10 s |
| Create Common Item | 1320 | 1 (level 1), 20 (level 2) | 0, 0 | Create Common Item (dwarf-style common craft levels), free; crafting, not combat |
| Common Craft | 1322 | 1 (level 1) | 0 | Common Craft, free; crafting, not combat |
| Anti Magic | 146 | 7 (levels 1–2), 14 (levels 3–4) | 260, 1100 | passive Anti Magic: M.Def +10/+12/+14/+16 |
| Armor Mastery | 244 | 7 (level 1), 14 (levels 2–3) | 520, 1100 | passive mystic Armor Mastery: P.Def +6.7/+8.0/+9.2 |
| Weapon Mastery | 249 | 7 (level 1), 14 (level 2) | 520, 2100 | passive mystic Weapon Mastery: P.Atk x1.45 then +1.5/+2.8, M.Atk x1.17 then +1.9/+3.5; bow/pole: Casting Spd x0.7, Accuracy -9 |
| Heal | 1011 | 7 (levels 1–3), 14 (levels 4–6) | 170, 700 | heal target; power 49,58,67 / 83,95,107 HP; MP 2+8..5+17; 5000 ms; reuse 10 s |
| Cure Poison | 1012 | 7 (level 1) | 520 | cure poison on target; MP 2+8; 4000 ms; reuse 15 s |
| Shield | 1040 | 7 (level 1) | 520 | target buff Shield: P.Def x1.08, 20 min; MP 2+8; 4000 ms; reuse 6 s; TARGET_ONE, so it can be cast on oneself |
| Might | 1068 | 7 (level 1) | 520 | target buff Might: P.Atk x1.08, 20 min; MP 2+8; 4000 ms; reuse 6 s |
| Ice Bolt | 1184 | 7 (levels 1–2), 14 (levels 3–4) | 260, 1100 | magic attack Ice Bolt + slow (Speed x0.7); power 8,9 / 11,13; MP 2+7..3+12; 3100+200 ms; reuse 8 s |
| Battle Heal | 1015 | 14 (levels 1–3) | 700 | fast heal target; power 83,95,107 HP; MP 5+20..7+25; 2000 ms; reuse 3 s |
| Group Heal | 1027 | 14 (levels 1–3) | 700 | party heal; power 66,76,86 HP; MP 7+26..9+34; 7000 ms; reuse 25 s |
| Curse: Weakness | 1164 | 14 (level 1) | 2100 | debuff Curse: Weakness: target P.Atk x0.83 for 15 s; MP 1+2; 1500 ms; reuse 8 s |
| Wind Shackle | 1206 | 14 (level 1) | 2100 | debuff Wind Shackle: target Atk.Spd x0.83 for 15 s; MP 1+2; 1500 ms; reuse 8 s |
| Expertise S | 239 | 20 (level 1) | 0 | Expertise lvl 1 (D grade) granted free at 20: removes the grade penalty for D-grade gear |

Sources: [DEVjEXTREME/L2jaCis-409](https://github.com/DEVjEXTREME/L2jaCis-409/blob/master/aCis_datapack/data/xml/classes/elvenMystic.xml), [Hl4p3x/L2JServer_C6_Interlude](https://github.com/Hl4p3x/L2JServer_C6_Interlude/blob/master/dist/db_installer/sql/install/skill_trees.sql).

### Dark Fighter

| Skill | Id | Learned at | SP per skill level | What it does |
|---|---|---|---|---|
| Lucky | 194 | 1 (level 1) | 0 | passive Lucky (skill type LUCK): no EXP lost on death at low level (handled in core, not by a stat) |
| Create Common Item | 1320 | 1 (level 1), 20 (level 2) | 0, 0 | Create Common Item (dwarf-style common craft levels), free; crafting, not combat |
| Common Craft | 1322 | 1 (level 1) | 0 | Common Craft, free; crafting, not combat |
| Power Strike | 3 | 5 (levels 1–3), 10 (levels 4–6), 15 (levels 7–9) | 50, 310, 950 | active melee physical attack (sword/blunt only); power 25,27,30 / 39,42,46 / 60,65,70; MP 10-19; 1080+720 ms; reuse 13 s; soulshot boosts skill power x2 |
| Mortal Blow | 16 | 5 (levels 1–3), 10 (levels 4–6), 15 (levels 7–9) | 50, 310, 950 | active dagger-only BLOW; power 73,80,88 / 115,126,137 / 178,193,210; MP 9-17; 1080+720 ms; reuse 11 s; chance-based (see blow mechanic) |
| Power Shot | 56 | 5 (levels 1–3), 10 (levels 4–6), 15 (levels 7–9) | 50, 310, 950 | active bow-only physical shot, range 700; power 65,71,78 / 102,112,122 / 158,172,187; MP 19-37; 3200+800 ms; reuse 25 s |
| Defense Aura | 91 | 5 (level 1) | 160 | self buff P.Def x1.08 for 20 min; MP 1+4; 4000 ms cast |
| Weapon Mastery | 141 | 5 (level 1), 10 (level 2), 15 (level 3) | 160, 910, 2900 | passive fighter Weapon Mastery: P.Atk x1.085 then +2/+3/+4 |
| Armor Mastery | 142 | 5 (level 1), 10 (levels 2–3), 15 (levels 4–5) | 160, 460, 1400 | passive fighter Armor Mastery: P.Def +9/+11/+12/+13/+14; Evasion +3 at levels 4-5 |
| Attack Aura | 77 | 10 (level 1) | 910 | self buff P.Atk x1.08 for 20 min; MP 2+5; 4000 ms cast |
| Drain Health | 70 | 15 (levels 1–2) | 1400 | active magic drain (dark element); power 20 / 22; heals caster 20% of damage dealt; MP 3+9 / 3+10; 3000 ms; reuse 15 s |
| Shadow Sense | 294 | 15 (level 1) | 2900 | passive Shadow Sense: Accuracy +3 at night only |
| Expertise S | 239 | 20 (level 1) | 0 | Expertise lvl 1 (D grade) granted free at 20: removes the grade penalty for D-grade gear |

Sources: [DEVjEXTREME/L2jaCis-409](https://github.com/DEVjEXTREME/L2jaCis-409/blob/master/aCis_datapack/data/xml/classes/darkFighter.xml), [Hl4p3x/L2JServer_C6_Interlude](https://github.com/Hl4p3x/L2JServer_C6_Interlude/blob/master/dist/db_installer/sql/install/skill_trees.sql).

### Dark Mystic

| Skill | Id | Learned at | SP per skill level | What it does |
|---|---|---|---|---|
| Magician's Movement | 118 | 1 (level 1) | 0 | passive Magician's Movement: Atk. Spd x0.8 unless wearing a robe (using kind MAGIC = robe armor type) (aCis only, L2J has no row) |
| Spellcraft | 163 | 1 (level 1) | 0 | passive Spellcraft: Casting Spd x0.5 unless wearing a robe (the mystic armor penalty) |
| Lucky | 194 | 1 (level 1) | 0 | passive Lucky (skill type LUCK): no EXP lost on death at low level (handled in core, not by a stat) |
| Mana Recovery | 214 | 1 (level 1) | 0 | passive Mana Recovery: MP regen x1.2 while wearing a robe |
| Wind Strike | 1177 | 1 (level 1), 7 (levels 2–3), 14 (levels 4–5) | 0, 240, 1100 | magic attack Wind Strike; power 12 (lvl1, free at 1), 13,15 / 18,21; MP 2+7..3+12; 4000 ms; reuse 6 s |
| Self Heal | 1216 | 1 (level 1) | 0 | Self Heal (free at 1): 42 HP; MP 2+7; 5000 ms; reuse 10 s |
| Create Common Item | 1320 | 1 (level 1), 20 (level 2) | 0, 0 | Create Common Item (dwarf-style common craft levels), free; crafting, not combat |
| Common Craft | 1322 | 1 (level 1) | 0 | Common Craft, free; crafting, not combat |
| Anti Magic | 146 | 7 (levels 1–2), 14 (levels 3–4) | 240, 1100 | passive Anti Magic: M.Def +10/+12/+14/+16 |
| Armor Mastery | 244 | 7 (level 1), 14 (levels 2–3) | 470, 1100 | passive mystic Armor Mastery: P.Def +6.7/+8.0/+9.2 |
| Weapon Mastery | 249 | 7 (level 1), 14 (level 2) | 470, 2100 | passive mystic Weapon Mastery: P.Atk x1.45 then +1.5/+2.8, M.Atk x1.17 then +1.9/+3.5; bow/pole: Casting Spd x0.7, Accuracy -9 |
| Heal | 1011 | 7 (levels 1–3), 14 (levels 4–6) | 160, 700 | heal target; power 49,58,67 / 83,95,107 HP; MP 2+8..5+17; 5000 ms; reuse 10 s |
| Cure Poison | 1012 | 7 (level 1) | 470 | cure poison on target; MP 2+8; 4000 ms; reuse 15 s |
| Shield | 1040 | 7 (level 1) | 470 | target buff Shield: P.Def x1.08, 20 min; MP 2+8; 4000 ms; reuse 6 s; TARGET_ONE, so it can be cast on oneself |
| Might | 1068 | 7 (level 1) | 470 | target buff Might: P.Atk x1.08, 20 min; MP 2+8; 4000 ms; reuse 6 s |
| Curse: Poison | 1168 | 7 (level 1) | 470 | poison DoT Curse: Poison: 24 HP every 3 s x10 (30 s); land rate 70; MP 2+8; reuse 12 s |
| Ice Bolt | 1184 | 7 (levels 1–2), 14 (levels 3–4) | 240, 1100 | magic attack Ice Bolt + slow (Speed x0.7); power 8,9 / 11,13; MP 2+7..3+12; 3100+200 ms; reuse 8 s |
| Battle Heal | 1015 | 14 (levels 1–3) | 700 | fast heal target; power 83,95,107 HP; MP 5+20..7+25; 2000 ms; reuse 3 s |
| Group Heal | 1027 | 14 (levels 1–3) | 700 | party heal; power 66,76,86 HP; MP 7+26..9+34; 7000 ms; reuse 25 s |
| Vampiric Touch | 1147 | 14 (levels 1–2) | 1100 | active magic drain Vampiric Touch (dark); power 18 / 21; heals caster 40% of damage; MP 5+20 / 6+22; 4000 ms; reuse 12 s |
| Wind Shackle | 1206 | 14 (level 1) | 2100 | debuff Wind Shackle: target Atk.Spd x0.83 for 15 s; MP 1+2; 1500 ms; reuse 8 s |
| Expertise S | 239 | 20 (level 1) | 0 | Expertise lvl 1 (D grade) granted free at 20: removes the grade penalty for D-grade gear |

Sources: [DEVjEXTREME/L2jaCis-409](https://github.com/DEVjEXTREME/L2jaCis-409/blob/master/aCis_datapack/data/xml/classes/darkMystic.xml), [Hl4p3x/L2JServer_C6_Interlude](https://github.com/Hl4p3x/L2JServer_C6_Interlude/blob/master/dist/db_installer/sql/install/skill_trees.sql).

### Orc Fighter

| Skill | Id | Learned at | SP per skill level | What it does |
|---|---|---|---|---|
| Toughness | 134 | 1 (level 1) | 0 | passive orc racial Toughness: modifies root/sleep/poison vulnerability by 20 (addMul; sign semantics not verified) |
| Lucky | 194 | 1 (level 1) | 0 | passive Lucky (skill type LUCK): no EXP lost on death at low level (handled in core, not by a stat) |
| Create Common Item | 1320 | 1 (level 1), 20 (level 2) | 0, 0 | Create Common Item (dwarf-style common craft levels), free; crafting, not combat |
| Common Craft | 1322 | 1 (level 1) | 0 | Common Craft, free; crafting, not combat |
| Power Strike | 3 | 5 (levels 1–3), 10 (levels 4–6), 15 (levels 7–9) | 60, 460, 1300 | active melee physical attack (sword/blunt only); power 25,27,30 / 39,42,46 / 60,65,70; MP 10-19; 1080+720 ms; reuse 13 s; soulshot boosts skill power x2 |
| Iron Punch | 29 | 5 (levels 1–3), 10 (levels 4–6), 15 (levels 7–9) | 60, 460, 1300 | active fist-weapon (dualfist) physical attack; power 29,31,34 / 45,49,54 / 69,76,82; MP 11-22; 1604+296 ms; reuse 15 s |
| Weapon Mastery | 141 | 5 (level 1), 10 (level 2), 15 (level 3) | 190, 1300, 4000 | passive fighter Weapon Mastery: P.Atk x1.085 then +2/+3/+4 |
| Armor Mastery | 142 | 5 (level 1), 10 (levels 2–3), 15 (levels 4–5) | 190, 690, 2000 | passive fighter Armor Mastery: P.Def +9/+11/+12/+13/+14; Evasion +3 at levels 4-5 |
| Relax | 226 | 5 (level 1) | 190 | toggle Relax: while sitting, HP regen +5; drains 2 MP per 2 s |
| Iron Body | 295 | 15 (level 1) | 4000 | passive Iron Body: fall damage x0.6 |
| Expertise S | 239 | 20 (level 1) | 0 | Expertise lvl 1 (D grade) granted free at 20: removes the grade penalty for D-grade gear |

Sources: [DEVjEXTREME/L2jaCis-409](https://github.com/DEVjEXTREME/L2jaCis-409/blob/master/aCis_datapack/data/xml/classes/orcFighter.xml), [Hl4p3x/L2JServer_C6_Interlude](https://github.com/Hl4p3x/L2JServer_C6_Interlude/blob/master/dist/db_installer/sql/install/skill_trees.sql).

### Orc Mystic

| Skill | Id | Learned at | SP per skill level | What it does |
|---|---|---|---|---|
| Magician's Movement | 118 | 1 (level 1) | 0 | passive Magician's Movement: Atk. Spd x0.8 unless wearing a robe (using kind MAGIC = robe armor type) (aCis only, L2J has no row) |
| Toughness | 134 | 1 (level 1) | 0 | passive orc racial Toughness: modifies root/sleep/poison vulnerability by 20 (addMul; sign semantics not verified) |
| Spellcraft | 163 | 1 (level 1) | 0 | passive Spellcraft: Casting Spd x0.5 unless wearing a robe (the mystic armor penalty) |
| Lucky | 194 | 1 (level 1) | 0 | passive Lucky (skill type LUCK): no EXP lost on death at low level (handled in core, not by a stat) |
| Mana Recovery | 214 | 1 (level 1) | 0 | passive Mana Recovery: MP regen x1.2 while wearing a robe |
| Soul Cry | 1001 | 1 (level 1), 14 (level 2) | 0, 1800 | toggle Soul Cry: P.Atk +4.5 (lvl1) / +14 (lvl2); costs 3 / 6 MP every 3 s |
| Create Common Item | 1320 | 1 (level 1), 20 (level 2) | 0, 0 | Create Common Item (dwarf-style common craft levels), free; crafting, not combat |
| Common Craft | 1322 | 1 (level 1) | 0 | Common Craft, free; crafting, not combat |
| Anti Magic | 146 | 7 (levels 1–2), 14 (levels 3–4) | 260, 880 | passive Anti Magic: M.Def +10/+12/+14/+16 |
| Weapon Mastery | 250 | 7 (level 1), 14 (level 2) | 520, 1800 | passive orc-mystic Weapon Mastery (same table as 249) |
| Robe Mastery | 251 | 7 (levels 1–2), 14 (levels 3–4) | 260, 880 | passive Robe Mastery: P.Def +11.6/+13.4/+16.1/+18.4 (robe) |
| Light Armor Mastery | 252 | 7 (levels 1–2), 14 (levels 3–4) | 260, 880 | passive Light Armor Mastery: P.Def +12.6..+19.3; Casting Spd x1.9, Atk.Spd x1.25, MP regen x1.2 in light armor |
| Soul Shield | 1010 | 7 (level 1) | 520 | target buff Soul Shield: P.Def x1.08, 20 min; MP 2+8; 2500 ms; reuse 5 s; TARGET_ONE, so it can be cast on oneself |
| Life Drain | 1090 | 7 (level 1), 14 (level 2) | 520, 1800 | active magic drain Life Drain; power 15 / 21; heals caster 80% of damage; MP 5+22 / 8+32; 4000 ms; reuse 6 s |
| Venom | 1095 | 7 (level 1), 14 (level 2) | 520, 1800 | poison DoT Venom: 24 / 36 HP every 3 s x10 (30 s); land rate 70; MP 2+8 / 3+12; 4000 ms (L2J hitTime); reuse 12 s |
| Dreaming Spirit | 1097 | 7 (level 1), 14 (level 2) | 520, 1800 | debuff Dreaming Spirit: sleep 30 s; land rate 80; MP 2+8 / 3+12; reuse 6 s |
| Chill Flame | 1100 | 7 (level 1), 14 (level 2) | 520, 1800 | fire DoT Chill Flame: 20 / 30 HP every 1 s x15 (300 / 450 total); land rate 70; MP 3+12 / 5+18; 4000 ms; reuse 6 s |
| Heavy Armor Mastery | 253 | 14 (levels 1–2) | 880 | passive Heavy Armor Mastery: P.Def +11.6/+13.3 (heavy); Casting Spd x1.71, Atk.Spd x1.25 |
| Chant of Battle | 1007 | 14 (level 1) | 1800 | party buff Chant of Battle: P.Atk x1.08, 20 min; MP 12+48; 2500 ms; reuse 20 s |
| Fear | 1092 | 14 (level 1) | 1800 | debuff Fear: target flees, 10 x 2 s; land rate 40; MP 3+12; 4000 ms; reuse 30 s |
| Expertise S | 239 | 20 (level 1) | 0 | Expertise lvl 1 (D grade) granted free at 20: removes the grade penalty for D-grade gear |

Sources: [DEVjEXTREME/L2jaCis-409](https://github.com/DEVjEXTREME/L2jaCis-409/blob/master/aCis_datapack/data/xml/classes/orcMystic.xml), [Hl4p3x/L2JServer_C6_Interlude](https://github.com/Hl4p3x/L2JServer_C6_Interlude/blob/master/dist/db_installer/sql/install/skill_trees.sql).

## The Monument of Heroes

- **Monument of Heroes**: Yes, an Interlude name: 'Monument of Heroes', an OlympiadManager NPC (an obelisk/statue). NPC ids 31690 (human-style, used in most towns), 31769 elf, 31770 dark elf, 31771 orc, 31772 dwarf; level 70, alias 'obelisk' in aCis. Its dialogue (olympiad/hero_main.htm): 'You are a Noblesse. Welcome. I offer many things - but only for Heroes.' with options to receive Hero weapons, the Wings of Destiny Circlet, and to see who is the Hero of this era. Spawned once in each of 16 towns, same coordinates in both packs: Talking Island Village (-85096,241516), Gludin (-84816,151008), Gludio (-15104,122040), Dion (16256,144256), Giran (82118,147524), Oren (82752,53056), Heine (112336,220208), Hunters Village (116096,77856), Aden (147504,27408), Rune (36048,-48268), Goddard (147408,-55232), Schuttgart (87664,-143472) all 31690; Elven Village (44602,50979) 31769, Dark Elven Village (9760,16656) 31770, Orc Village (-45360,-114688) 31771, Dwarven Village (115488,-179664) 31772. Town names are assigned from the coordinates (and spawn-territory names), not stated in the files. Sources: [github:DEVjEXTREME/L2jaCis-409](https://github.com/DEVjEXTREME/L2jaCis-409/blob/master/aCis_datapack/data/xml/npcs/31000-31999.xml), [github:DEVjEXTREME/L2jaCis-409](https://github.com/DEVjEXTREME/L2jaCis-409/blob/master/aCis_datapack/data/xml/spawnlist/), [github:DEVjEXTREME/L2jaCis-409](https://github.com/DEVjEXTREME/L2jaCis-409/blob/master/aCis_datapack/data/html/olympiad/hero_main.htm), [github:Hl4p3x/L2JServer_C6_Interlude](https://github.com/Hl4p3x/L2JServer_C6_Interlude/blob/master/dist/db_installer/sql/install/npc.sql), [github:Hl4p3x/L2JServer_C6_Interlude](https://github.com/Hl4p3x/L2JServer_C6_Interlude/blob/master/dist/db_installer/sql/install/spawnlist.sql).

## What the game calls them

- **SP is "skill points", for every class** **(single source)**: There is no "spell points". The Human Mystic's Newbie Guide: "SP means "skill points," and they are consumed whenever you learn new skills or magic." The mage tutorial: "You'll need to build your skill points (SP) by hunting monsters." System messages: "You have acquired $s1 SP.", "Your SP has decreased by $s1.", and id 278 "You do not have enough SP to learn this skill." Sources: aCis `aCis_datapack/data/html/script/feature/NewbieHelper/human/guide_human_cnacelot_m07_04.htm`, `.../Tutorial/tutorial_mage020.htm`, `aCis_gameserver/.../network/SystemMessageId.java`; L2J `dist/game/data/scripts/ai/others/Tutorial/tutorial_mage017.htm`; the L2J family only.
- **A hit is counted in damage** **(single source)**: The client's combat messages name what a blow takes as "damage": id 35 "You hit for $s1 damage." and ids 36 and 37 "$s1 hit you for $s2 damage.", and id 44 "Critical hit!" on its own. aCis drops the full stop on 35. Sources: aCis `aCis_gameserver/java/net/sf/l2j/gameserver/network/SystemMessageId.java` (`YOU_DID_S1_DMG`, `S1_GAVE_YOU_S2_DMG`), [github:Hl4p3x/L2JServer_C6_Interlude](https://github.com/Hl4p3x/L2JServer_C6_Interlude/blob/master/java/org/l2jserver/gameserver/network/SystemMessageId.java) (`YOU_HIT_FOR_S1_DAMAGE`, `S1_HIT_YOU_FOR_S2_DAMAGE`); the L2J family only.
- **A mystic's spells are skills** **(single source)**: The Talking Island mystic trainers (Magister Baulro 30033, Priest Yohanes 30032) offer "Learn skills"; Baulro is "in charge of teaching magic here". The tutorial heads its page "[ Learning Magic ]" and speaks of "magic skills", and a guide says "Active skills, including spells, must be intentionally used." In the data, magic is a flag on a skill (`isMagic`), not a kind of its own. A mystic skill is learned with a book, "Spellbook: Wind Strike" (item 1150). The client's skill window labels were not checked. Sources: aCis `aCis_datapack/data/html/trainer/30033.htm`, `30032.htm`, `.../NewbieHelper/orc/guide_orc_tanai_m07_041.htm`, `aCis_datapack/data/xml/spellbooks.xml`.
- **What a weapon does to a mystic's casting**: No first-tier mystic skill has a weapon condition (see Weapon conditions above). The mystic Weapon Mastery (249; 250 for the Orc Mystic) multiplies Casting Spd by 0.7 and takes 9 Accuracy while a bow or a polearm is worn (`<using kind="BOW,POLE"/>`). Spellcraft (163, every mystic from level 1) halves Casting Spd unless robe armour is worn. Sources: aCis `aCis_datapack/data/xml/skills/0200-0299.xml`, `0100-0199.xml`; L2J `dist/game/data/stats/skills/0200-0299.xml`.
- **A passive multiplies before it adds**: a stat's functions run lowest order first, whatever order the skill lists them in. L2J writes the order into the data (`<mul order="0x30">`, `<add order="0x40">`), and aCis into the function (`FuncMul` 20, `FuncAdd` 30, sorted by `Calculator.addFunc`). So the mystic Weapon Mastery, whose data lists its adds first, multiplies P.Atk by 1.45 and M.Atk by 1.17 and then adds 1.5 and 1.9, as the fighter's multiplies by 1.085 and then adds 2. Sources: aCis `aCis_gameserver/java/net/sf/l2j/gameserver/skills/basefuncs/FuncMul.java`, `FuncAdd.java`, `skills/Calculator.java`; L2J `dist/game/data/stats/skills/0100-0199.xml`, `0200-0299.xml`.

## Disputes and caveats

What the checks could not settle, kept as the checker wrote it.

- Base-class trees re-confirmed: aCis classes/*.xml and L2J skill_trees.sql agree row for row (skill, level, SP, min level) for all 8 base classes up to level 20, except Magician's Movement (118), which only aCis gives the four mystics (free at 1).
- Previously established numbers re-confirmed in both packs: Wind Strike, Ice Bolt, Power Strike, Mortal Blow, Power Shot, Iron Punch, Chill Flame, Soul Cry (L2J Iron Punch has a 25-entry magicLvl table for 24 levels, a datapack bug).
- SP costs differ by race for the same skill: Power Strike lvl 4-6 costs 370 SP (Human), 310 (Elf, Dark Elf), 460 (Orc); lvl 7-9 1300 / 1100 / 950 / 1300.
- MP is given as initial + on-completion (mpInitialConsume + mpConsume); l2hub shows the sum (Vampiric Touch lvl1 = 25).
- Disagreements: physical damage constant 77 (aCis) vs 70 (L2J); melee swing 500000 vs 470000 / PAtkSpd; magic crit x4 vs x3; blow chance model (aCis DEX- and position-scaled from baseLandRate 200, cap 80%) vs L2J flat 50/60/70% (its DEX term is an integer-division no-op); night hit penalty -20 points (aCis) vs x0.9 (L2J); magic fail base 1.166 vs 1.3.
- Lucky (194) and Toughness (134) one-liners are partly from general L2 knowledge: Lucky has no stat block in either pack (handled in core), Toughness's addMul sign was not traced.
- l2hub.info was used only for Vampiric Touch and Shadow Sense; its NPC page for the monument returned 404.
- Downloads were read as data only, under dl_c/; nothing was executed.
