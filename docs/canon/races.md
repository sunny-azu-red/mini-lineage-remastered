# Races and starting gear

Part of the Lineage II canon (Interlude, C6): the reference the game takes names and numbers from.
It is not a roadmap. Read [README.md](README.md) before using an entry.

Each race's level-1 template and what a new character of each set carries in the real game.

## Races

- **Human**: Template level-1 HP: Human Fighter 80, Human Mystic 101 (MP 30/40, CP 32/50.5). Mystic STR/CON/DEX/INT/WIT/MEN 22/27/21/41/20/39, Fighter 40/43/30/21/11/25. Run speed 115 (Fighter) / 120 (Mystic). The all-rounder. Sources: [github:DEVjEXTREME/L2jaCis-409](https://github.com/DEVjEXTREME/L2jaCis-409/blob/main/aCis_datapack/data/xml/classes/humanMystic.xml), [github:Hl4p3x/L2JServer_C6_Interlude](https://github.com/Hl4p3x/L2JServer_C6_Interlude/blob/HEAD/dist/game/data/stats/playerTemplates.xml), [lineage.pmfun.com](https://lineage.pmfun.com/list/stat).
- **Elf**: Template level-1 HP: Elven Fighter 89, Elven Mystic 104. Fighter 36/36/35/23/14/26, Mystic 21/25/24/37/23/40. Run speed 125 (Fighter) / 122 (Mystic). High DEX and speed. Buffers: Elven Oracle, Elven Elder. Sources: [github:DEVjEXTREME/L2jaCis-409](https://github.com/DEVjEXTREME/L2jaCis-409/blob/main/aCis_datapack/data/xml/classes/elvenFighter.xml), [github:Hl4p3x/L2JServer_C6_Interlude](https://github.com/Hl4p3x/L2JServer_C6_Interlude/blob/HEAD/dist/game/data/stats/playerTemplates.xml).
- **Dark Elf**: Template level-1 HP: Dark Fighter 94, Dark Mystic 106. Fighter 41/32/34/25/12/26, Mystic 23/24/23/44/19/37. Run speed 122. High STR/INT, low CON. Follow Shilen; buffers Shillien Oracle and Shillien Elder. Base classes are "Dark Fighter" and "Dark Mystic". Sources: [github:DEVjEXTREME/L2jaCis-409](https://github.com/DEVjEXTREME/L2jaCis-409/blob/main/aCis_datapack/data/xml/classes/darkFighter.xml), [github:Hl4p3x/L2JServer_C6_Interlude](https://github.com/Hl4p3x/L2JServer_C6_Interlude/blob/HEAD/dist/game/data/stats/playerTemplates.xml), [l2hub.info](https://l2hub.info/il/classes/dark_fighter).
- **Orc**: Template level-1 HP: Orc Fighter 80, Orc Mystic 95. Fighter 40/47/26/18/12/27 (highest CON). Orc Mystic 27/31/24/31/15/42 in both L2J packs (pmfun differs). Run speed 117 (Fighter) / 121 (Mystic), as `movement.md` has it. Base mystic class is "Orc Mage"; Orc Shaman/Warcryer/Overlord give chants. Sources: [github:DEVjEXTREME/L2jaCis-409](https://github.com/DEVjEXTREME/L2jaCis-409/blob/main/aCis_datapack/data/xml/classes/orcFighter.xml), [github:Hl4p3x/L2JServer_C6_Interlude](https://github.com/Hl4p3x/L2JServer_C6_Interlude/blob/HEAD/dist/game/data/stats/playerTemplates.xml).
- **Dwarf**: Fighter only ("Dwarven Fighter"). Template level-1 HP 80, MP 30, CP 56. Stats 39/45/29/20/10/27, run speed 115. Crafting (Artisan/Warsmith) and spoiling (Scavenger/Bounty Hunter). Sources: [github:DEVjEXTREME/L2jaCis-409](https://github.com/DEVjEXTREME/L2jaCis-409/blob/main/aCis_datapack/data/xml/classes/dwarfFighter.xml), [github:Hl4p3x/L2JServer_C6_Interlude](https://github.com/Hl4p3x/L2JServer_C6_Interlude/blob/HEAD/dist/game/data/stats/playerTemplates.xml), [l2hub.info](https://l2hub.info/il/classes/dwarven_fighter).

## Starting gear

- **Human Fighter / Elven Fighter / Dark Fighter starting items**: Squire's Shirt (No-grade light chest, P.Def 33), Squire's Pants (light legs, P.Def 20), Squire's Sword (P.Atk 6, M.Atk 5), Dagger (P.Atk 5, M.Atk 5), Tutorial Guide. Item ids 1146, 1147, 2369, 10, 5588. Confirmed by a third datapack (l2j-interlude char_templates: classes 0, 18, 31). Stats confirmed by l2hub. Sources: [l2hub.info](https://l2hub.info/il/items/squire's_shirt), [github:Hl4p3x/L2JServer_C6_Interlude](https://github.com/Hl4p3x/L2JServer_C6_Interlude/blob/master/dist/game/data/stats/playerTemplates.xml).
- **Human / Elven / Dark Elven mystic starting items**: Apprentice's Tunic (No-grade robe chest, P.Def 17), Apprentice's Stockings (robe legs, P.Def 10), Apprentice's Wand (1H blunt, P.Atk 5, M.Atk 7), Tutorial Guide. Item ids 425, 461, 6, 5588 (char_templates classes 10, 25, 38). Sources: [l2hub.info](https://l2hub.info/il/items/apprentice's_wand), [github:Hl4p3x/L2JServer_C6_Interlude](https://github.com/Hl4p3x/L2JServer_C6_Interlude/blob/master/dist/game/data/stats/playerTemplates.xml).
- **Orc Fighter starting items**: Squire's Shirt, Squire's Pants, Training Gloves (fist weapon, P.Atk 7, M.Atk 5), Squire's Sword, Tutorial Guide. Training Gloves replace the Dagger (char_templates class 44). Sources: [l2hub.info](https://l2hub.info/il/items/training_gloves), [github:DEVjEXTREME/L2jaCis-409](https://github.com/DEVjEXTREME/L2jaCis-409/blob/main/aCis_datapack/data/xml/classes/orcFighter.xml).
- **Orc Mystic starting items**: Apprentice's Tunic, Apprentice's Stockings, Training Gloves, Tutorial Guide. There is no wand (char_templates class 49). Sources: [github:DEVjEXTREME/L2jaCis-409](https://github.com/DEVjEXTREME/L2jaCis-409/blob/main/aCis_datapack/data/xml/classes/orcMystic.xml), [github:Hl4p3x/L2JServer_C6_Interlude](https://github.com/Hl4p3x/L2JServer_C6_Interlude/blob/master/dist/game/data/stats/playerTemplates.xml).
- **Dwarven Fighter starting items**: Squire's Shirt, Squire's Pants, Dagger, Guild Member's Club (1H blunt, P.Atk 6, M.Atk 5), Tutorial Guide. The club replaces the Squire's Sword (char_templates class 53). Sources: [l2hub.info](https://l2hub.info/il/items/guild_member's_club), [github:DEVjEXTREME/L2jaCis-409](https://github.com/DEVjEXTREME/L2jaCis-409/blob/main/aCis_datapack/data/xml/classes/dwarfFighter.xml).

## Lore

- **Elf vs Dark Elf** **(uncertain: check again before use)**: Dark Elves descend from Elves who turned to dark magic and Shilen, goddess of death, and were cast out; Elves follow Eva. Only search snippets of two fan wikis support this; not fetched. Sources: [lineage2.fandom.com](https://lineage2.fandom.com/el/wiki/Dark_Elf), [l2revolution.fandom.com](https://l2revolution.fandom.com/wiki/Dark_Elf?oldid=4792).

## Disputes and caveats

What the checks could not settle, kept as the checker wrote it.

- Race HP and stat figures are raw L2J template values before the CON bonus. Orc Mystic stats differ on pmfun.
- Lore entry kept as uncertain: the fandom pages could not be fetched.
