# Movement, reach and aggression

Part of the Lineage II canon (Interlude, C6): the reference the game takes names and numbers from.
It is not a roadmap. Read [README.md](README.md) before using an entry.

How far everything reaches and how fast it moves: every monster's attack range, walk and run speed
and aggression, the cast range of every spell the game's monsters and starting sets use, every
weapon's attack range, the starting classes' run speed, the two slows, and how an aggressive monster
notices a player while a passive one waits to be hit. **Reach is settled**: melee 40, a bow 500, a
spell 600 (Power Shot 700, Shield and Soul Shield 400, three monster slows 1000, Aura Burn 150), in
every source. **Speed is not**: see the disputes at the end before a rule uses a monster's run speed.

## Sources

| Key | What | Where |
|---|---|---|
| **L2J (db)** | L2J Interlude datapack, david-buzas: `npc.sql`, `char_templates.sql`, `weapon.sql`, skill XML | https://github.com/david-buzas/l2j-interlude-datapack/tree/master/src/main/resources (`sql/` and `data/stats/skills/`) |
| **L2J (Hl4p3x)** | Hl4p3x L2JServer_C6_Interlude: `npc.sql`, `playerTemplates.xml`, `statBonus.xml`, item and skill XML, Java core | https://github.com/Hl4p3x/L2JServer_C6_Interlude (`dist/db_installer/sql/install/npc.sql`, `dist/game/data/stats/`, `java/org/l2jserver/gameserver/`) |
| **aCis** | aCis 409 mirror, DEVjEXTREME/L2jaCis-409: NPC, skill, item and class XML, AI scripts, Java core, `npcs.properties` | https://github.com/DEVjEXTREME/L2jaCis-409 (`aCis_datapack/data/xml/`, `aCis_gameserver/`) |
| **l2hub** | l2hub.info Interlude pages (PTS-derived), fetched 2026-10-14 | `https://l2hub.info/il/npcs/<alias>`, `https://l2hub.info/il/skills/<id>`, `https://l2hub.info/il/items/<alias>` |

## Monsters: attack range, speed, aggression

All 97 rows were produced by a script and checked with assertions:

- L2J (db) and L2J (Hl4p3x) agree on level, `attackrange`, `walkspd`, `runspd`, `aggro` and
  `faction_range` for all 97.
- aCis `baseAttackRange` equals L2J `attackrange` for all 97, and the level matches the game's.
- aCis `walkSpd` and `runSpd` are **exactly 0.9 ×** L2J's for all 97 (walk and run).
- **Aggressive: 27 yes, 70 no, and all three sources agree on every row**: L2J `aggro` 500 against
  0; the aCis AI class (one ending in `Aggressive`, whose `onSeeCreature` attacks); the l2hub `agro`
  flag and AI class (`warrior_aggressive*`, `wizard_ag_*`).
- aCis `aggroRange` and l2hub "Agro Range" are 1000 for all 97, so they do not tell aggressive from
  passive.
- Attack range is 40 for every melee monster and 500 for the five the game marks `bow` (Orc Archer,
  Kaboo Orc Archer, Balor Orc Archer, Dungeon Skeleton Archer, Skeleton Longbowman). The game's
  `attack` column matches the sources on every row. l2hub shows no attack range (**MISSING** there),
  only the AI class (`*_use_bow`).
- DEX is 30 for all 97 in L2J, aCis and l2hub, so one DEX multiplier (1.10) applies to every row.

Columns: **Attack range**, **Walk/Run spd (L2J)** and **Aggro range (L2J)** are npc.sql columns 13,
36, 37 and 31. **Run spd (aCis)** is the `runSpd` set in `aCis_datapack/data/xml/npcs/20000-20999.xml`
(Gremlin 18342: `18000-18999.xml`). **Walk / run (l2hub)** is the page's `baseMovingSpeed`.
**aCis AI class** is the `_npcIds` list in `aCis_gameserver/java/net/sf/l2j/gameserver/scripting/script/ai/individual/Monster/**`
that holds the id. **Help range** is L2J `faction_range` (`faction_id`) against aCis `clanRange` (`clan`).
l2hub page URLs are the ones `docs/canon/monsters.md` cites for each monster.

| Monster | Id | Level | Attack range | Walk spd (L2J) | Run spd (L2J) | Run spd (aCis) | Aggressive | Aggro range (L2J) | Walk / run (l2hub) | aCis AI class | l2hub AI class | Help range (L2J faction_range / aCis clanRange) |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Young Keltir | 20545 | 1 | 40 | 25 | 121 | 108.9 | no | 0 | 23 / 110 | Warrior | warrior_passive | 0 / none |
| Bearded Keltir | 20481 | 1 | 40 | 25 | 121 | 108.9 | no | 0 | 23 / 110 | Warrior | warrior_passive | 0 / none |
| Elpy | 20432 | 1 | 40 | 55 | 88 | 79.2 | no | 0 | 50 / 80 | WarriorFlee | warrior_flee | 0 / none |
| Gremlin | 18342 | 1 | 40 | 22 | 55 | 49.5 | no | 0 | 20 / 50 | Warrior | warrior_passive | 0 / none |
| Elder Keltir | 20544 | 3 | 40 | 25 | 121 | 108.9 | no | 0 | 23 / 110 | Warrior | warrior_passive | 0 / none |
| Wolf | 20120 | 4 | 40 | 26 | 121 | 108.9 | no | 0 | 24 / 110 | Warrior | warrior_passive | 0 / none |
| Elder Wolf | 20442 | 5 | 40 | 26 | 121 | 108.9 | no | 0 | 24 / 110 | Warrior | warrior_passive | 0 / none |
| Giant Toad | 20121 | 5 | 40 | 55 | 110 | 99 | no | 0 | 50 / 100 | Warrior | warrior_passive | 0 / 300 (npc_clan_20121) |
| Orc | 20130 | 6 | 40 | 49 | 121 | 108.9 | no | 0 | 45 / 110 | Warrior | warrior_passive | 300 (orc_clan) / 300 (orc_clan) |
| Orc Grunt | 20131 | 7 | 40 | 49 | 121 | 108.9 | no | 0 | 45 / 110 | Warrior | warrior_passive | 300 (orc_clan) / 300 (orc_clan) |
| Goblin Scout | 20326 | 8 | 40 | 44 | 121 | 108.9 | no | 0 | 40 / 110 | Warrior | warrior_passive | 300 (goblin_clan) / 300 (goblin_clan) |
| Orc Archer | 20006 | 8 | 500 | 49 | 121 | 108.9 | no | 0 | 45 / 110 | WarriorUseBow | warrior_passive_use_bow | 300 (orc_clan) / 300 (orc_clan) |
| Werewolf | 20132 | 9 | 40 | 55 | 132 | 118.8 | no | 0 | 50 / 120 | Warrior | warrior_passive | 300 (werewolf_clan) / 300 (werewolf_clan) |
| Orc Fighter | 20093 | 10 | 40 | 49 | 121 | 108.9 | yes | 500 | 45 / 110 | WarriorAggressive | warrior_aggressive | 300 (orc_clan) / 300 (orc_clan) |
| Werewolf Hunter | 20343 | 10 | 40 | 55 | 132 | 118.8 | yes | 500 | 50 / 120 | WarriorAggressive | warrior_aggressive | 300 (werewolf_clan) / 300 (werewolf_clan) |
| Orc Lieutenant | 20096 | 11 | 40 | 49 | 121 | 108.9 | no | 0 | 45 / 110 | Warrior | warrior_passive | 300 (orc_clan) / 300 (orc_clan) |
| Werewolf Chieftain | 20342 | 12 | 40 | 55 | 132 | 118.8 | yes | 500 | 50 / 120 | WarriorAggressive | warrior_aggressive | 300 (werewolf_clan) / 300 (werewolf_clan) |
| Orc Fighter Leader | 20098 | 12 | 40 | 49 | 121 | 108.9 | yes | 500 | 45 / 110 | WarriorCastingEnchantSelfAggressive | warrior_aggressive_casting_enchant_self | 300 (orc_clan) / 300 (orc_clan) |
| Stone Golem | 20016 | 13 | 40 | 25 | 25 | 22.5 | no | 0 | 23 / 23 | WarriorSlowType1 | warrior_pa_slow_type1 | 0 / 300 (npc_clan_20016) |
| Crasher | 20101 | 14 | 40 | 25 | 25 | 22.5 | no | 0 | 23 / 23 | WarriorSlowType1 | warrior_pa_slow_type1 | 0 / 300 (npc_clan_20101) |
| Talon Spider | 20106 | 16 | 40 | 79 | 143 | 128.7 | no | 0 | 72 / 130 | Warrior | warrior_passive | 0 / 300 (npc_clan_20106) |
| Blade Spider | 20108 | 17 | 40 | 79 | 143 | 128.7 | yes | 500 | 72 / 130 | WarriorAggressive | warrior_aggressive | 0 / 300 (npc_clan_20108) |
| Young Red Keltir | 20530 | 1 | 40 | 25 | 121 | 108.9 | no | 0 | 23 / 110 | Warrior | warrior_passive | 0 / none |
| Red Keltir | 20534 | 2 | 40 | 25 | 121 | 108.9 | no | 0 | 23 / 110 | Warrior | warrior_passive | 0 / none |
| Elder Red Keltir | 20537 | 3 | 40 | 25 | 121 | 108.9 | no | 0 | 23 / 110 | Warrior | warrior_passive | 0 / none |
| Gray Wolf | 20525 | 4 | 40 | 26 | 121 | 108.9 | no | 0 | 24 / 110 | Warrior | warrior_passive | 0 / none |
| Goblin Raider | 20325 | 5 | 40 | 44 | 121 | 108.9 | no | 0 | 40 / 110 | Warrior | warrior_passive | 300 (goblin_clan) / 300 (goblin_clan) |
| Kaboo Orc | 20468 | 6 | 40 | 49 | 121 | 108.9 | no | 0 | 45 / 110 | Warrior | warrior_passive | 300 (orc_clan) / 300 (orc_clan) |
| Kaboo Orc Grunt | 20470 | 7 | 40 | 49 | 121 | 108.9 | no | 0 | 45 / 110 | Warrior | warrior_passive | 300 (orc_clan) / 300 (orc_clan) |
| Green Dryad | 20336 | 8 | 40 | 44 | 121 | 108.9 | no | 0 | 40 / 110 | Warrior | warrior_passive | 0 / 300 (npc_clan_20336) |
| Kaboo Orc Archer | 20469 | 8 | 500 | 49 | 121 | 108.9 | no | 0 | 45 / 110 | WarriorUseBow | warrior_passive_use_bow | 300 (orc_clan) / 300 (orc_clan) |
| Spore Fungus | 20509 | 9 | 40 | 77 | 121 | 108.9 | no | 0 | 70 / 110 | Warrior | warrior_passive | 0 / 300 (npc_clan_20509) |
| Kaboo Orc Fighter | 20471 | 10 | 40 | 49 | 121 | 108.9 | yes | 500 | 45 / 110 | WarriorAggressive | warrior_aggressive | 300 (orc_clan) / 300 (orc_clan) |
| Baraq Orc Fighter | 20372 | 10 | 40 | 49 | 121 | 108.9 | yes | 500 | 45 / 110 | WarriorAggressive | warrior_aggressive | 300 (orc_clan) / 300 (orc_clan) |
| Baraq Orc Warrior Leader | 20373 | 11 | 40 | 49 | 121 | 108.9 | no | 0 | 45 / 110 | Warrior | warrior_passive | 300 (orc_clan) / 300 (orc_clan) |
| Dungeon Skeleton | 20464 | 12 | 40 | 66 | 154 | 138.6 | yes | 500 | 60 / 140 | WarriorAggressive | warrior_aggressive | 300 (skeleton_clan) / 300 (skeleton_clan) |
| Dungeon Skeleton Archer | 20463 | 13 | 500 | 44 | 154 | 138.6 | no | 0 | 40 / 140 | WarriorUseBow | warrior_passive_use_bow | 300 (skeleton_clan) / 300 (skeleton_clan) |
| Dread Soldier | 20504 | 14 | 40 | 66 | 154 | 138.6 | yes | 500 | 60 / 140 | WarriorAggressive | warrior_aggressive | 300 (skeleton_clan) / 300 (skeleton_clan) |
| Mist Terror | 20371 | 15 | 40 | 110 | 110 | 99 | yes | 500 | 100 / 100 | WarriorAggressive | warrior_aggressive | 0 / 300 (npc_clan_20371) |
| Dark Terror | 20345 | 16 | 40 | 110 | 110 | 99 | yes | 500 | 100 / 100 | WarriorCastingCurseAggressive | warrior_aggressive_casting_curse | 0 / 300 (npc_clan_20345) |
| Shade Horror | 20033 | 17 | 40 | 110 | 110 | 99 | no | 0 | 100 / 100 | WarriorCastingCurse | warrior_passive_casting_curse | 0 / 300 (npc_clan_20033) |
| Sukar Wererat | 20040 | 18 | 40 | 88 | 132 | 118.8 | no | 0 | 80 / 120 | Warrior | warrior_passive | 300 (wererat_clan) / 300 (wererat_clan) |
| Sukar Wererat Leader | 20047 | 19 | 40 | 88 | 132 | 118.8 | yes | 500 | 80 / 120 | WarriorAggressive | warrior_aggressive | 300 (wererat_clan) / 300 (wererat_clan) |
| Dre Vanul Tracker | 20351 | 20 | 40 | 88 | 88 | 79.2 | yes | 500 | 80 / 80 | WarriorCastHoldMagicAggressive | warrior_aggressive_casting_hold_magic | 300 (demonic_clan) / 300 (demonic_clan) |
| Young Brown Keltir | 20529 | 1 | 40 | 25 | 121 | 108.9 | no | 0 | 23 / 110 | Warrior | warrior_passive | 0 / none |
| Brown Keltir | 20532 | 2 | 40 | 25 | 121 | 108.9 | no | 0 | 23 / 110 | Warrior | warrior_passive | 0 / none |
| Elder Brown Keltir | 20536 | 3 | 40 | 25 | 121 | 108.9 | no | 0 | 23 / 110 | Warrior | warrior_passive | 0 / none |
| Ashen Wolf | 20456 | 4 | 40 | 26 | 121 | 108.9 | no | 0 | 24 / 110 | Warrior | warrior_passive | 0 / none |
| Goblin | 20003 | 5 | 40 | 44 | 121 | 108.9 | no | 0 | 40 / 110 | Warrior | warrior_passive | 300 (goblin_clan) / 300 (goblin_clan) |
| Imp | 20004 | 6 | 40 | 66 | 88 | 79.2 | no | 0 | 60 / 80 | Warrior | warrior_passive | 300 (demonic_clan) / 300 (demonic_clan) |
| Imp Elder | 20005 | 7 | 40 | 66 | 88 | 79.2 | no | 0 | 60 / 80 | Warrior | warrior_passive | 300 (demonic_clan) / 300 (demonic_clan) |
| Balor Orc Archer | 20385 | 8 | 500 | 49 | 121 | 108.9 | no | 0 | 45 / 110 | WarriorUseBow | warrior_passive_use_bow | 300 (orc_clan) / 300 (orc_clan) |
| Goblin Lookout | 20328 | 8 | 40 | 44 | 121 | 108.9 | no | 0 | 40 / 110 | Warrior | warrior_passive | 300 (goblin_clan) / 300 (goblin_clan) |
| Green Fungus | 20007 | 9 | 40 | 77 | 121 | 108.9 | no | 0 | 70 / 110 | Warrior | warrior_passive | 0 / 300 (npc_clan_20007) |
| Balor Orc Fighter | 20386 | 10 | 40 | 49 | 121 | 108.9 | yes | 500 | 45 / 110 | WarriorAggressive | warrior_aggressive | 300 (orc_clan) / 300 (orc_clan) |
| Goblin Thief | 20321 | 10 | 40 | 44 | 121 | 108.9 | no | 0 | 40 / 110 | Warrior | warrior_passive | 300 (goblin_clan) / 300 (goblin_clan) |
| Vaiss Orc | 20381 | 10 | 40 | 49 | 121 | 108.9 | no | 0 | 45 / 110 | Warrior | warrior_passive | 300 (orc_clan) / 300 (orc_clan) |
| Balor Orc Lieutenant | 20388 | 11 | 40 | 49 | 121 | 108.9 | no | 0 | 45 / 110 | Warrior | warrior_passive | 300 (orc_clan) / 300 (orc_clan) |
| Vaiss Orc Warrior Leader | 20382 | 11 | 40 | 49 | 121 | 108.9 | no | 0 | 45 / 110 | Warrior | warrior_passive | 300 (orc_clan) / 300 (orc_clan) |
| Balor Orc Fighter Leader | 20387 | 12 | 40 | 49 | 121 | 108.9 | yes | 500 | 45 / 110 | WarriorAggressive | warrior_aggressive | 300 (orc_clan) / 300 (orc_clan) |
| Blood Fungus | 20400 | 12 | 40 | 77 | 121 | 108.9 | no | 0 | 70 / 110 | Warrior | warrior_passive | 0 / 300 (npc_clan_20400) |
| Skeleton Hunter | 20517 | 12 | 40 | 66 | 154 | 138.6 | yes | 500 | 60 / 140 | WarriorAggressive | warrior_aggressive | 300 (skeleton_clan) / 300 (skeleton_clan) |
| Doom Soldier | 20455 | 14 | 40 | 66 | 154 | 138.6 | yes | 500 | 60 / 140 | WarriorAggressive | warrior_aggressive | 300 (skeleton_clan) / 300 (skeleton_clan) |
| Cave Spider | 20348 | 15 | 40 | 79 | 143 | 128.7 | no | 0 | 72 / 130 | Warrior | warrior_passive | 0 / 300 (npc_clan_20348) |
| Cave Fang Spider | 20350 | 16 | 40 | 79 | 143 | 128.7 | yes | 500 | 72 / 130 | WarriorAggressive | warrior_aggressive | 0 / 300 (npc_clan_20350) |
| Omen Beast | 20031 | 17 | 40 | 33 | 132 | 118.8 | no | 0 | 30 / 120 | Warrior | warrior_passive | 0 / 300 (npc_clan_20031) |
| Tainted Zombie | 20041 | 18 | 40 | 16 | 16 | 14.4 | no | 0 | 15 / 15 | WarriorSlowType2 | warrior_pa_slow_type2 | 0 / 300 (npc_clan_20041) |
| Stink Zombie | 20046 | 19 | 40 | 16 | 16 | 14.4 | no | 0 | 15 / 15 | WarriorSlowType2 | warrior_pa_slow_type2 | 0 / 300 (npc_clan_20046) |
| Lesser Succubus | 20048 | 20 | 40 | 66 | 110 | 99 | yes | 500 | 60 / 100 | WarriorCastSleepMagicAggressive | warrior_aggressive_casting_sleep_magic | 300 (demonic_clan) / 300 (demonic_clan) |
| Lesser Succubus Turen | 20052 | 21 | 40 | 66 | 110 | 99 | yes | 500 | 60 / 100 | WizardDDMagic2Aggressive | wizard_ag_ddmagic2 | 300 (demonic_clan) / 300 (demonic_clan) |
| Lesser Succubus Tilfo | 20057 | 22 | 40 | 66 | 110 | 99 | yes | 500 | 60 / 100 | WarriorCastHoldMagicAggressive | warrior_aggressive_casting_hold_magic | 300 (demonic_clan) / 300 (demonic_clan) |
| Young Prairie Keltir | 20531 | 1 | 40 | 25 | 121 | 108.9 | no | 0 | 23 / 110 | Warrior | warrior_passive | 0 / none |
| Prairie Keltir | 20535 | 2 | 40 | 25 | 121 | 108.9 | no | 0 | 23 / 110 | Warrior | warrior_passive | 0 / none |
| Elder Prairie Keltir | 20538 | 3 | 40 | 25 | 121 | 108.9 | no | 0 | 23 / 110 | Warrior | warrior_passive | 0 / none |
| Kasha Wolf | 20475 | 4 | 40 | 26 | 121 | 108.9 | no | 0 | 24 / 110 | Warrior | warrior_passive | 0 / none |
| Goblin Grave Robber | 20319 | 5 | 40 | 44 | 121 | 108.9 | no | 0 | 40 / 110 | Warrior | warrior_passive | 300 (goblin_clan) / 300 (goblin_clan) |
| Rakeclaw Imp | 20311 | 6 | 40 | 66 | 88 | 79.2 | no | 0 | 60 / 80 | Warrior | warrior_passive | 300 (demonic_clan) / 300 (demonic_clan) |
| Kasha Timber Wolf | 20477 | 6 | 40 | 26 | 121 | 108.9 | no | 0 | 24 / 110 | Warrior | warrior_passive | 0 / none |
| Rakeclaw Imp Hunter | 20312 | 7 | 40 | 66 | 88 | 79.2 | no | 0 | 60 / 80 | Warrior | warrior_passive | 300 (demonic_clan) / 300 (demonic_clan) |
| Mountain Fungus | 20365 | 8 | 40 | 77 | 121 | 108.9 | no | 0 | 70 / 110 | Warrior | warrior_passive | 0 / 300 (npc_clan_20365) |
| Maraku Werewolf | 20363 | 9 | 40 | 55 | 132 | 118.8 | no | 0 | 50 / 120 | Warrior | warrior_passive | 300 (werewolf_clan) / 300 (werewolf_clan) |
| Evil Eye | 20426 | 10 | 40 | 99 | 147 | 132.3 | no | 0 | 90 / 134 | WizardDDMagic2 | wizard_pa_ddmagic2 | 0 / 300 (npc_clan_20426) |
| Evil Eye Watcher | 20427 | 10 | 40 | 99 | 147 | 132.3 | no | 0 | 90 / 134 | WizardDDMagic2 | wizard_pa_ddmagic2 | 0 / 300 (npc_clan_20427) |
| Darkwing Bat | 20316 | 11 | 40 | 66 | 88 | 79.2 | no | 0 | 60 / 80 | Warrior | warrior_passive | 0 / 300 (npc_clan_20316) |
| Grizzly | 20143 | 12 | 40 | 44 | 121 | 108.9 | yes | 500 | 40 / 110 | WarriorAggressive | warrior_aggressive | 0 / 300 (npc_clan_20143) |
| Goblin Tomb Raider Leader | 20320 | 12 | 40 | 44 | 121 | 108.9 | no | 0 | 40 / 110 | Warrior | warrior_passive | 300 (goblin_clan) / 300 (goblin_clan) |
| Slave Skeleton | 20340 | 12 | 40 | 66 | 154 | 138.6 | yes | 500 | 60 / 140 | WarriorAggressive | warrior_aggressive | 300 (skeleton_clan) / 300 (skeleton_clan) |
| Greystone Golem | 20333 | 13 | 40 | 25 | 25 | 22.5 | no | 0 | 23 / 23 | WarriorSlowType1 | warrior_pa_slow_type1 | 0 / 300 (npc_clan_20333) |
| Grave Keeper | 20368 | 13 | 40 | 25 | 25 | 22.5 | no | 0 | 23 / 23 | WarriorSlowType1 | warrior_pa_slow_type1 | 0 / 300 (npc_clan_20368) |
| Evil Eye Patroller | 20428 | 14 | 40 | 99 | 147 | 132.3 | no | 0 | 90 / 134 | WizardDDMagic2 | wizard_pa_ddmagic2 | 0 / 300 (npc_clan_20428) |
| Crypt Horror | 20491 | 15 | 40 | 110 | 110 | 99 | yes | 500 | 100 / 100 | WarriorAggressive | warrior_aggressive | 0 / 300 (npc_clan_20491) |
| Kuruka Ratman | 20487 | 16 | 40 | 88 | 132 | 118.8 | no | 0 | 80 / 120 | Warrior | warrior_passive | 300 (wererat_clan) / 300 (wererat_clan) |
| Kuruka Ratman Hunter | 20488 | 17 | 40 | 88 | 132 | 118.8 | no | 0 | 80 / 120 | Warrior | warrior_passive | 300 (wererat_clan) / 300 (wererat_clan) |
| Skeleton Longbowman | 20542 | 19 | 500 | 44 | 154 | 138.6 | yes | 500 | 40 / 140 | WarriorAggressive | warrior_aggressive_use_bow | 0 / none |
| Undead Slave | 20341 | 19 | 40 | 16 | 16 | 14.4 | no | 0 | 15 / 15 | WarriorSlowType2 | warrior_pa_slow_type2 | 0 / 300 (npc_clan_20341) |
| Ghost | 20543 | 20 | 40 | 88 | 154 | 138.6 | yes | 500 | 80 / 140 | WarriorAggressive | warrior_aggressive | 0 / none |
| Ghost Guardian | 20329 | 21 | 40 | 88 | 154 | 138.6 | yes | 500 | 80 / 140 | WarriorAggressive | warrior_aggressive | 0 / none |

**What the server actually moves at** (the template speed × the DEX bonus, see "Character run speed" for the
code): L2J (Hl4p3x) runs `int(runspd × 1.1)`, so a 121 monster moves at 133. aCis runs
`runSpd × DEX_BONUS[30] = 108.9 × 1.10 ≈ 119.8`. The PTS-derived figure is l2hub's 110 × 1.10 = 121,
which is the figure L2J *stores*. So L2J's npc.sql already includes the DEX bonus, and Hl4p3x applies
it a second time. That last point is an inference from the ratios, not something either codebase
says.

### Hand spot-checks (raw rows read by eye)

| Monster | L2J (db) npc.sql row, the relevant fields | L2J (Hl4p3x) | aCis XML | aCis AI | l2hub |
|---|---|---|---|---|---|
| Young Keltir 20545 | attackrange 40, aggro 0, walkspd 25, runspd 121, faction NULL | identical | baseAttackRange 40, walkSpd 22.5, runSpd 108.9, aggroRange 1000, no clan | Warrior.java | [23/110, agro false, warrior_passive](https://l2hub.info/il/npcs/young_keltir) |
| Orc Archer 20006 | attackrange 500, aggro 0, walkspd 49, runspd 121, orc_clan 300, rhand 14 (Bow) | identical | 500, 44.1, 108.9, 1000, orc_clan 300 | WarriorUseBow.java | [45/110, agro false, warrior_passive_use_bow](https://l2hub.info/il/npcs/orc_archer) |
| Orc Fighter 20093 | attackrange 40, aggro 500, walkspd 49, runspd 121, orc_clan 300 | identical | 40, 44.1, 108.9, 1000, orc_clan 300, AI param SetAggressiveTime 0 | WarriorAggressive.java | 45/110, agro true, warrior_aggressive |
| Stone Golem 20016 | attackrange 40, aggro 0, walkspd 25, runspd 25, faction NULL | identical | 40, 22.5, 22.5, 1000, npc_clan_20016 300 | WarriorSlowType1.java | 23/23, agro false, warrior_pa_slow_type1 |
| Ghost Guardian 20329 | attackrange 40, aggro 500, walkspd 88, runspd 154, faction NULL | identical | 40, 79.2, 138.6, 1000, no clan | WarriorAggressive.java | 80/140, agro true, warrior_aggressive |
| Evil Eye Watcher 20427 | attackrange 40, aggro 0, walkspd 99, runspd 147, faction NULL | identical | 40, 89.1, 132.3, 1000, npc_clan_20427 300 | WizardDDMagic2.java | 90/134, agro false, wizard_pa_ddmagic2 |

All six agree with the generated table.

## Monster spell cast ranges

Only six monster spells are in `monsters.csv`. All three datapacks and l2hub agree on every cast
range. Effect range is how far the target may move away before the cast fails (L2J and aCis only).

| Spell | Id | Cast range | Effect range | Target / type | Cast by (game) | Sources |
|---|---|---|---|---|---|---|
| NPC Windstrike - Magic | 4151 | 600 | 1100 | one, MDAM | Evil Eye, Evil Eye Patroller | L2J (db) and L2J (Hl4p3x) `skills/4100-4199.xml`; aCis `skills/4100-4199.xml`; [l2hub](https://l2hub.info/il/skills/4151) |
| NPC HP Drain - Magic | 4152 | 600 | 1100 | one, DRAIN | Evil Eye Watcher, Lesser Succubus Turen | same files; [l2hub](https://l2hub.info/il/skills/4152) |
| NPC Aura Burn - Magic | 4160 | 150 | 650 | one, MDAM | Evil Eye, Evil Eye Watcher, Evil Eye Patroller, Lesser Succubus Turen | same files; [l2hub](https://l2hub.info/il/skills/4160) |
| NPC Windstrike - Slow | 4247 | 1000 | 1500 | one, MDAM | Stone Golem, Crasher, Grave Keeper, Undead Slave | `skills/4200-4299.xml` in all three; [l2hub](https://l2hub.info/il/skills/4247) |
| NPC HP Drain - Slow | 4248 | 1000 | 1500 | one, MDAM in both emulators (l2hub: i_hp_drain 5,20) | Stink Zombie | same; [l2hub](https://l2hub.info/il/skills/4248) |
| NPC Prominence - Slow | 4254 | 1000 | 1500 | one, MDAM | Greystone Golem | same; [l2hub](https://l2hub.info/il/skills/4254) |

Monster skills the canon lists but the game leaves out, for completeness (same four sources, all agree):
NPC Might 4028 is self-only (L2J −1, aCis none, l2hub −1); Poison 4035 is 600 (effect range 1100);
Decrease Speed 4076 (L2J calls it "Reduction in movement speed") is 600 (1100); Hold 4047 is 600 (1100).

How the AI picks between them, which matters for the 150-range Aura Burn: in aCis, `WizardDDMagic2`
(Evil Eyes) casts its long-range spell (`W_LONG_RANGE_DD_MAGIC`, 4151/4152) when the target is more
than 100 away in 2D, and its short-range one (`W_SHORT_RANGE_DD_MAGIC`, 4160) otherwise
(`scripting/script/ai/individual/Monster/WizardBase/Wizard/WizardDDMagic2/WizardDDMagic2.java`
lines 79, 125 and 161; the long-range branch is taken on 80% of the hits at line 79).
`WarriorSlowType1` casts `DD_MAGIC_SLOW` at its most hated target (`WarriorSlowType.java` lines 70 and 85).

## Character skill cast ranges

Every active skill in `trainer.csv`, and Venom, which the game leaves out; the masteries are
passive and have no range. All four sources agree on every value. In L2J, −1 means self; aCis
leaves the field out for self-target skills; l2hub shows −1 for self buffs and 0 for toggles.

| Skill | Id | Cast range | Effect range | Target | Kind | Weapon required |
|---|---|---|---|---|---|---|
| Power Strike | 3 | 40 | 400 | one | PDAM | sword, blunt, two-handed sword, two-handed blunt (aCis `SWORD,BLUNT,BIGBLUNT,BIGSWORD`; L2J mask 18444) |
| Mortal Blow | 16 | 40 | 400 | one | BLOW | dagger (L2J mask 16) |
| Iron Punch | 29 | 40 | 400 | one | PDAM | fists (`DUALFIST`, L2J mask 1024) |
| Power Shot | 56 | 700 | 1200 | one | PDAM | bow (L2J mask 32) |
| Drain Health | 70 | 600 | 1100 | one | DRAIN | |
| Wind Strike | 1177 | 600 | 1100 | one | MDAM | |
| Ice Bolt | 1184 | 600 | 1100 | one | MDAM plus a slow | |
| Vampiric Touch | 1147 | 600 | 1100 | one | DRAIN | |
| Chill Flame | 1100 | 600 | 1100 | one | DOT | |
| Life Drain | 1090 | 600 | 1100 | one | DRAIN | |
| Curse: Poison | 1168 | 600 | 1100 | one | POISON | |
| Venom | 1095 | 600 | 1100 | one | POISON | |
| Wind Shackle | 1206 | 600 | 1100 | one | DEBUFF | |
| Heal | 1011 | 600 | 1100 | one | HEAL | |
| Shield | 1040 | 400 | 900 | one | BUFF | |
| Soul Shield | 1010 | 400 | 900 | one | BUFF | |
| Self Heal | 1216 | self (−1) | | self | HEAL | |
| Elemental Heal | 58 | self (−1) | | self | HEAL | |
| Attack Aura | 77 | self (−1; L2J (Hl4p3x) omits) | | self | BUFF | |
| Defense Aura | 91 | self (−1 in L2J (db); Hl4p3x and aCis omit) | | self | BUFF | |
| Relax | 226 | self (toggle; l2hub 0) | | self | CONT | |
| Soul Cry | 1001 | self (toggle; l2hub 0) | | self | CONT | |

Files: L2J (db) `src/main/resources/data/stats/skills/{0000-0099,0200-0299,1000-1099,1100-1199,1200-1299}.xml`;
L2J (Hl4p3x) `dist/game/data/stats/skills/` (same file names); aCis `aCis_datapack/data/xml/skills/`
(same file names); l2hub `https://l2hub.info/il/skills/<id>` (the page's `castRange`, the same at
every level of every skill checked).

Melee skills at 40 use the same 40 as a melee swing. Both cores add the two collision radii to that
range when they decide whether the target is in reach (for example L2J (Hl4p3x) `ai/AttackableAI.java`
line 753: `getPhysicalAttackRange() + own collision radius + target's collision radius`).

## Weapon attack range by type

**By type:**

| Weapon type | L2J (Hl4p3x) | aCis 409 |
|---|---|---|
| Bow | 40 base + 460 = **500** (`FuncBowAtkRange`, players only) | **500** (`WeaponType.BOW`) |
| Pole | **66** in each pole's item XML (`<set stat="pAtkRange" val="66">` on 90 poles; 80 on the 9 "Towering Blow" poles; 4 poles have none and stay 40) | **66** (`WeaponType.POLE`) |
| Every other type (sword, blunt, dagger, fist, dualfist, dual, two-handed sword or blunt, etc, none, pet) | **40** (base) | **40** |

- L2J (Hl4p3x): `java/org/l2jserver/gameserver/datatables/xml/PlayerTemplateData.java` line 81
  sets every player's `baseAtkRange` to 40. `model/skills/Formulas.java` lines 311 to 334 define
  `FuncBowAtkRange` (+460 to `pAtkRange` when a bow is equipped), and line 932 adds it to players
  only. Range is `calcStat(POWER_ATTACK_RANGE, baseAtkRange)` (`model/actor/stat/CreatureStat.java`
  line 828). A pole's 66 is also the default splash radius in `Creature.doAttackHitByPole`
  (`model/actor/Creature.java` line 1300). One sword and one dagger also carry a stray
  `pAtkRange 66` in Hl4p3x's item XML; neither is in the game.
- aCis: `aCis_gameserver/java/net/sf/l2j/gameserver/enums/items/WeaponType.java` (NONE 40, SWORD 40,
  BLUNT 40, DAGGER 40, BOW 500, POLE 66, ETC 40, FIST 40, DUAL 40, DUALFIST 40, BIGSWORD 40,
  FISHINGROD 40, BIGBLUNT 40, PET 40). A player's range is
  `calcStat(POWER_ATTACK_RANGE, attackType.getRange())` (`model/actor/status/PlayerStatus.java`
  line 1078). A monster uses its template's `baseAttackRange` (`model/actor/status/NpcStatus.java`
  line 46). aCis item XML also carries an `attack_range` per weapon, read in the table below; it
  matches `WeaponType` for every weapon here.
- l2hub gives a weapon's type (`weaponType`) but no attack range: **MISSING** there.

**Every no-grade weapon the village traders listed** (by canon name: the game's `items.csv`
renames Dagger to Squire's Dagger, Training Gloves to Squire's Gloves and Apprentice's Spellbook to
Scholar's Tome, leaves out Apprentice's Rod, Doom Dagger, Orcish Sword and Handmade Sword, and adds
its own Squire's Bow, a bow at 500; types read from L2J (db) `weapon.sql`, L2J (Hl4p3x)
`dist/game/data/stats/items/*.xml` and aCis `aCis_datapack/data/xml/items/*.xml`, matched by name).
No pole is in the game, so every game weapon is 40 or 500.

| Weapon (canon) | Game type | Hands | Item id | L2J weapon.sql type | L2J (Hl4p3x) XML type | L2J range | aCis type | aCis attack_range |
|---|---|---|---|---|---|---|---|---|
| Apprentice's Wand | staff | 1 | 6 | blunt (rhand) | blunt | 40 (base) | BLUNT | 40 |
| Apprentice's Rod (also id 1300, same type) | staff | 1 | 7 | blunt (rhand) | blunt | 40 (base) | BLUNT | 40 |
| Short Bow | bow | 2 | 13 | bow (lrhand) | bow | 40 + 460 = 500 (FuncBowAtkRange) | BOW | 500 |
| Bow (also id 1307, same type) | bow | 2 | 14 | bow (lrhand) | bow | 40 + 460 = 500 (FuncBowAtkRange) | BOW | 500 |
| Hunting Bow | bow | 2 | 271 | bow (lrhand) | bow | 40 + 460 = 500 (FuncBowAtkRange) | BOW | 500 |
| Forest Bow | bow | 2 | 272 | bow (lrhand) | bow | 40 + 460 = 500 (FuncBowAtkRange) | BOW | 500 |
| Dagger | dagger | 1 | 10 | dagger (rhand) | dagger | 40 (base) | DAGGER | 40 |
| Bone Dagger | dagger | 1 | 11 | dagger (rhand) | dagger | 40 (base) | DAGGER | 40 |
| Knife (also id 1305, same type) | dagger | 1 | 12 | dagger (rhand) | dagger | 40 (base) | DAGGER | 40 |
| Doom Dagger | dagger | 1 | 215 | dagger (rhand) | dagger | 40 (base) | DAGGER | 40 |
| Dirk | dagger | 1 | 216 | dagger (rhand) | dagger | 40 (base) | DAGGER | 40 |
| Throwing Knife | dagger | 1 | 218 | dagger (rhand) | dagger | 40 (base) | DAGGER | 40 |
| Training Gloves | fists | 2 | 2368 | dualfist (lrhand) | dualfist | 40 (base) | DUALFIST | 40 |
| Spiked Gloves | fists | 2 | 253 | dualfist (lrhand) | dualfist | 40 (base) | DUALFIST | 40 |
| Iron Gloves | fists | 2 | 254 | dualfist (lrhand) | dualfist | 40 (base) | DUALFIST | 40 |
| Fox Claw Gloves | fists | 2 | 255 | dualfist (lrhand) | dualfist | 40 (base) | DUALFIST | 40 |
| Cestus | fists | 2 | 256 | dualfist (lrhand) | dualfist | 40 (base) | DUALFIST | 40 |
| Buffalo's Horn | staff | 1 | 308 | etc (rhand) | etc | 40 (base) | ETC | 40 |
| Apprentice's Spellbook | staff | 1 | 99 | etc (rhand) | etc | 40 (base) | ETC | 40 |
| Relic of The Saints | staff | 1 | 310 | etc (rhand) | etc | 40 (base) | ETC | 40 |
| Squire's Sword | sword | 1 | 2369 | sword (rhand) | sword | 40 (base) | SWORD | 40 |
| Short Sword | sword | 1 | 1 | sword (rhand) | sword | 40 (base) | SWORD | 40 |
| Broadsword | sword | 1 | 3 | sword (rhand) | sword | 40 (base) | SWORD | 40 |
| Gladius (also id 1296, same type) | sword | 1 | 66 | sword (rhand) | sword | 40 (base) | SWORD | 40 |
| Orcish Sword | sword | 1 | 67 | sword (rhand) | sword | 40 (base) | SWORD | 40 |
| Handmade Sword | sword | 1 | 122 | sword (rhand) | sword | 40 (base) | SWORD | 40 |
| Long Sword (also id 1295, same type) | sword | 1 | 2 | sword (rhand) | sword | 40 (base) | SWORD | 40 |
| Willow Staff | staff | 2 | 8 | bigblunt (lrhand) | bigblunt | 40 (base) | BIGBLUNT | 40 |
| Cedar Staff | staff | 2 | 9 | bigblunt (lrhand) | bigblunt | 40 (base) | BIGBLUNT | 40 |
| Journeyman's Staff | staff | 2 | 176 | bigblunt (lrhand) | bigblunt | 40 (base) | BIGBLUNT | 40 |
| Brandish | sword | 2 | 1333 | bigsword (lrhand) | bigsword | 40 (base) | BIGSWORD | 40 |
| Zweihander | sword | 2 | 5284 | bigsword (lrhand) | bigsword | 40 (base) | BIGSWORD | 40 |

The datapacks' types are finer than the game's: the game's `staff` covers L2 `blunt` (Apprentice's
Wand and Rod), `etc` (Buffalo's Horn, Apprentice's Spellbook, Relic of The Saints) and `bigblunt`
(the two-handed staves); its two-handed `sword` is L2 `bigsword`; its `fists` is L2 `dualfist`. The
range is 40 for all of them either way. The "also id" copies are lighter duplicate items with the same
name and type.

## Character run speed, the eight starting classes

| Class | Class id | Run spd (template) | Walk spd (aCis) | DEX | DEX bonus | Run spd in game (template × DEX bonus, rounded down) |
|---|---|---|---|---|---|---|
| Human Fighter | 0 | 115 | 80 | 30 | 1.10 | 126 |
| Human Mystic | 10 | 120 | 78 | 21 | 1.01 | 121 |
| Elven Fighter | 18 | 125 | 90 | 35 | 1.15 | 143 |
| Elven Mystic | 25 | 122 | 85 | 24 | 1.04 | 126 |
| Dark Fighter | 31 | 122 | 85 | 34 | 1.14 | 139 |
| Dark Mystic | 38 | 122 | 85 | 23 | 1.03 | 125 |
| Orc Fighter | 44 | 117 | 70 | 26 | 1.06 | 124 |
| Orc Mystic | 49 | 121 | 70 | 24 | 1.04 | 125 |

- **Template run speed**: L2J (db) `char_templates.sql` column `MOVE_SPD`; L2J (Hl4p3x)
  `dist/game/data/stats/playerTemplates.xml` `baseRunSpd`; aCis
  `aCis_datapack/data/xml/classes/<class>.xml` `runSpd`. All three agree on all eight. Unlike
  monsters, aCis does **not** scale player speeds by 0.9. aCis also gives `walkSpd`; L2J (Hl4p3x)
  sets `baseWalkSpd` 0 for players (`PlayerTemplateData.java` line 77), and `char_templates.sql`
  has no walk column, so walk is aCis only.
- **DEX** from `char_templates.sql` (column `DEX`), which `docs/canon/races.md` also gives.
- **DEX bonus**: L2J (Hl4p3x) `dist/game/data/stats/statBonus.xml`, `<DEX>` block (21 → 1.01,
  23 → 1.03, 24 → 1.04, 26 → 1.06, 30 → 1.1, 34 → 1.14, 35 → 1.15). aCis computes the same table
  as `floor(1.009^(DEX − 19.36) × 100 + 0.5) / 100` (`skills/Formulas.java` lines 61 to 64 and 101),
  which gives the same eight values.
- **The DEX multiplier is applied to run speed in both cores**: L2J (Hl4p3x)
  `model/skills/Formulas.java` lines 479 to 498 (`FuncMoveSpeed`: `value *= DEX bonus`), added for
  players (line 946) and in the shared NPC calculator (lines 904 to 905); the result is read by
  `CreatureStat.getRunSpeed()` (line 853), plus `RunSpeedBoost` (0) and capped at `MaxRunSpeed`
  (250) in `config/main/Physics.ini`. aCis `skills/funcs/FuncMoveSpeed.java` (`value × DEX_BONUS[DEX]`),
  added to every Creature in `model/actor/Creature.java` line 204.
- l2hub's class pages show no run speed, and `/il/classes/human_fighter` and the mystic pages
  return 404: **MISSING** from l2hub.
- The "in game" column is arithmetic on the sourced numbers above, not a figure read from any source.

## Ice Bolt and Wind Shackle effects

| Skill | Effect | Duration | Levels | Sources |
|---|---|---|---|---|
| **Ice Bolt 1184** | Run speed × **0.7** (−30%), a debuff that has to land: effectPower 60, resisted by MEN (`saveVs MEN` in L2J (Hl4p3x); L2J (db) and aCis name no save) | **120 s** | Same −30% at all 6 levels; damage power 8, 9, 11, 13, 14, 16 | L2J (db) `1100-1199.xml` (`<effect name="Buff" time="120" stackType="RunSpeedDown"><mul order="0x30" stat="runSpd" val="0.7"/>`); L2J (Hl4p3x) same file and values (effectPower 60, effectType DEBUFF); aCis `1100-1199.xml` (`<effect name="Debuff" time="120" effectPower="60" stackType="speed_down"><mul stat="runSpd" val="0.7"/>`); [l2hub](https://l2hub.info/il/skills/1184): `p_speed all −30 per` at every level, no duration shown |
| **Wind Shackle 1206** | Atk. Spd. × **0.83** at level 1 (−17%); × 0.8 at levels 2 to 5; × 0.77 at levels 6 to 19. A debuff with power 80 | **15 s** | 19 levels, magic level 14, 20, 25, 30, 35, 40, 44 … 74 | L2J (db) `1200-1299.xml` (`#Tab-pAtkSpd 0.83 0.8 0.8 0.8 0.8 0.77 …`, `<effect name="Buff" time="15" stackType="pAtkSpdDown"><mul order="0x30" stat="pAtkSpd" …/>`); L2J (Hl4p3x) same; aCis `1200-1299.xml` (`#pAtkSpd` same table, `<effect name="Debuff" time="15" stackType="attack_time_up">`); [l2hub](https://l2hub.info/il/skills/1206): `p_attack_speed all −17 per` at level 1, −20 at level 2, no duration shown |

The durations come from L2J and aCis only (they agree). l2hub's pages carry no abnormal time:
**MISSING** from l2hub.

## Aggro and passive monsters

### L2J (Hl4p3x core, L2J (db)/Hl4p3x npc.sql data)

- **Aggressive means `aggro` > 0**: `model/actor/instance/MonsterInstance.java` lines 105 to 107
  (`isAggressive() = getTemplate().getAggroRange() > 0 && !isEventMob`). The 27 aggressive monsters
  all have `aggro` 500, and the 70 passive ones 0.
- **Detection range is the monster's own `aggro`, 500**: `ai/AttackableAI.java`
  `autoAttackCondition` (from line 119) refuses a target outside `getAggroRange()` or more than 300
  apart in height (line 150), and requires `me.isAggressive()` and line of sight (line 284).
  `thinkActive` walks its known list and adds 1 hate to each target that passes (lines 390 to 440).
- **No aggression for 10 s after spawn**: `_globalAggro = -10`, counted up once a second
  (`AttackableAI.java` lines 72, 85 and 378 to 379).
- **Passive monsters engage only when attacked, or when called by their faction**: `thinkAttack`
  (from line 598) calls every NPC of the same `faction_id` (lines 687 to 702). It skips any NPC
  whose own `faction_range` is 0, uses the CALLED NPC's `faction_range` (300 for every faction
  monster here) as the radius, and needs the called NPC idle or active, in line of sight and within
  600 in height. 50 of the 97 have no faction (NULL, range 0) and so never help.

### aCis 409

- **`aggroRange` is 1000 for every monster**, and `Monster.isAggressive()` is `aggroRange > 0`
  (`model/actor/instance/Monster.java` line 246), so that flag is true for all of them. It is used
  only by `AggroList.reconsiderTarget` (line 144), which picks a new target within `aggroRange` when
  the monster cannot reach its current one (for example while immobilised).
- **Aggression comes from the AI class.** `WarriorAggressive.onSeeCreature` calls `tryToAttack`
  on any Playable it sees (`scripting/script/ai/individual/Monster/WarriorBase/Warrior/WarriorAggressive/WarriorAggressive.java`
  line 240), and so do `WarriorCastingEnchantSelfAggressive`, `WarriorCastingCurseAggressive`,
  `WarriorCastHoldMagicAggressive`, `WarriorCastSleepMagicAggressive` and
  `WizardDDMagic2Aggressive` (line 59, which casts at the player it sees). The passive classes
  (`Warrior`, `WarriorFlee`, `WarriorUseBow`, `WarriorSlowType1/2`, `WarriorCastingCurse`,
  `WizardDDMagic2`) do not. `WarriorBase.onSeeCreature` (line 289) attacks only under the AI
  parameters `HalfAggressive` or `RandomAggressive`, and none of the 97 has either.
- **`tryToAttack` needs the monster inside its own spawn territory**
  (`scripting/script/ai/individual/DefaultNpc.java` line 208). The AI parameter `SetAggressiveTime`
  falls back to 0 when unset (`getNpcIntAIParam`, line 136), and 0 attacks at once; only −1 waits
  for 3 to 7 s of the NPC's life (lines 213 to 218). None of the 97 sets −1; Orc Fighter sets 0
  explicitly.
- **Detection range is 450**: `DefaultSeeRange = 450` (`aCis_gameserver/config/npcs.properties`
  line 150), returned by `Npc.getSeeRange()` (`model/actor/Npc.java` lines 2279 to 2282). The
  see-creature checks use it: `model/actor/ai/type/NpcAI.java` line 471 (the AI tick),
  `Npc.lookNeighbor` (lines 2058 to 2081: at most once every 30 s, ignores targets more than 500
  apart in height) and `Creature.forceSeeCreature` (`model/actor/Creature.java` line 1933). The
  code comments there say "fixed 400 Aggro Range", which is stale against the 450 the config sets.
- **Passive monsters engage when attacked, or when a clan member within 300 is attacked**: the
  victim calls every NPC within its OWN `clanRange` (300) that shares its `clan`
  (`model/actor/Npc.java` lines 436 to 455). `Warrior.onClanAttacked` (`.../WarriorBase/Warrior/Warrior.java`
  line 439) then adds hate against a Playable attacker if the called NPC has lived more than 7 s.
  Unlike L2J, aCis gives each of the 27 monsters L2J leaves factionless a clan of its own,
  `npc_clan_<id>`, with range 300: Giant Toad, Stone Golem, Crasher, Talon Spider, Blade Spider,
  Green Dryad, Spore Fungus, Mist Terror, Dark Terror, Shade Horror, Green Fungus, Blood Fungus,
  Cave Spider, Cave Fang Spider, Omen Beast, Tainted Zombie, Stink Zombie, Mountain Fungus, Evil Eye,
  Evil Eye Watcher, Darkwing Bat, Grizzly, Greystone Golem, Grave Keeper, Evil Eye Patroller,
  Crypt Horror and Undead Slave. So in aCis those help their own species, and in L2J they do not.
  The 23 with no clan in either (the keltirs, wolves, Elpy, Gremlin, Skeleton Longbowman, Ghost and
  Ghost Guardian) never help in either.

### l2hub

- "Agro Range" 1000 for all 97, an `agro` true/false flag and the PTS AI class
  (`warrior_passive`, `warrior_aggressive`, `warrior_aggressive_casting_*`, `wizard_ag_ddmagic2`,
  `wizard_pa_ddmagic2`, `warrior_pa_slow_type*`, `*_use_bow`), which agree with L2J's 500/0 and
  aCis's AI class on all 97. l2hub gives no detection radius and no clan help range: **MISSING**.

### The aggro numbers side by side

| Rule | L2J | aCis | l2hub |
|---|---|---|---|
| Aggressive monsters (of 97) | 27 (`aggro` 500) | 27 (aggressive AI class) | 27 (`agro` flag) |
| Distance at which an aggressive monster notices you | 500 (`aggro`), height difference ≤ 300 | 450 (`DefaultSeeRange`), height difference ≤ 500 | MISSING (1000 shown as "Agro Range" for all) |
| Delay after spawn | 10 s (`_globalAggro`) | none (`SetAggressiveTime` unset, so 0) | MISSING |
| Clan or faction help radius | 300, the called NPC's `faction_range` (47 of 97 have one) | 300, the caller's `clanRange` (74 of 97 have one) | MISSING |

## Disputes and caveats

- **A monster's run speed has three readings.** L2J stores one figure (Young Keltir 121); aCis stores
  exactly 0.9 × L2J's on every row (108.9); l2hub's PTS-derived pages show L2J's ÷ 1.1, rounded
  (110). Both cores also multiply movement speed by the DEX bonus as they run, and every monster here
  has DEX 30 (× 1.10), so l2hub's 110 × 1.10 = 121 is the figure L2J *stores*: L2J's number already
  holds the DEX bonus, and L2J (Hl4p3x) applies it again (133). The double count is an inference from
  the ratios. A rule must pick one reading and say which.
- **A player's run speed is not scaled** by aCis's 0.9, and every source agrees on the eight
  templates; the DEX bonus still applies in play (a Human Fighter runs 126, an Elven Fighter 143).
  Walk speed is aCis's alone (single source).
- **How far an aggressive monster notices a player:** 500 in L2J (its `aggro`), 450 in aCis
  (`DefaultSeeRange`). l2hub's "Agro Range" is 1000 for every monster and decides nothing.
- **Who answers a clan member's call** differs: 27 monsters have no faction in L2J but a clan of
  their own species with range 300 in aCis, so golems, spiders, fungi and Evil Eyes help their own
  kind in aCis and not in L2J.
- **Slow durations** come from L2J and aCis only, which agree; l2hub shows none.
