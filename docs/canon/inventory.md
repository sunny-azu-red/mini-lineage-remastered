# The inventory and the village shops

Part of the Lineage II canon (Interlude, C6): the reference the game takes names and numbers from.
It is not a roadmap. Read [README.md](README.md) before using an entry.

Every equipment slot, what a naked character's stats are made of and how gear replaces them, the
inventory's limits, and what the four starting villages' traders sell. A shop's price is the
reference price plus 15% tax.

## The paperdoll

- **Equipment slots (paperdoll)**: Interlude has these worn slots: underwear (shirt slot; in Interlude it holds the Hemp/Cotton/Silk Cloak, Cotton/Wool Undergarment and the Tattoos), left earring, right earring, necklace, left ring, right ring, head, right hand (weapon), left hand (shield, or arrows for a bow), gloves, chest, legs, feet, face (hair accessory 1), hair (hair accessory 2), and a both-hair slot. Both codebases also declare a back/cloak slot but no Interlude item uses it (0 items with bodypart 'back'), so there is no cloak slot in play; the 'cloaks' of Interlude are underwear-slot items with P.Def 2-4. Earrings and rings are one item type each that fills the free one of the pair (left first, then right). A full-body armour (bodypart fullarmor, 74-75 items) sits in the chest slot and empties the legs slot; putting on legs removes a full-body chest. A two-handed weapon (lrhand: bows, two-handed swords and blunts, spears, dual fists such as Cestus, staves) empties the shield slot; equipping a shield takes off a two-handed weapon, except arrows may sit in the left hand with a bow. Formal Wear (alldress) takes chest and clears legs, both hands, head, feet and gloves. Sources: github.com/DEVjEXTREME/L2jaCis-409 aCis_gameserver/.../enums/Paperdoll.java and model/itemcontainer/Inventory.java equipItem(), github.com/Hl4p3x/L2JServer_C6_Interlude java/.../model/Inventory.java PAPERDOLL_* and equip/unequip, github.com/DEVjEXTREME/L2jaCis-409 data/xml/items/*.xml bodypart counts, github.com/Hl4p3x/L2JServer_C6_Interlude dist/game/data/stats/items/*.xml bodypart counts.

**Equipment slots (paperdoll): underwear examples**

| id | name | p_def |
|---|---|---|
| 52 | Hemp Cloak | 2 |
| 53 | Cotton Cloak | 3 |
| 54 | Silk Cloak | 4 |
| 55 | Cotton Undergarment | 4 |
| 56 | Wool Undergarment | 5 |
| 485 | Tattoo of Power | 53 |

## Naked stats, and how gear replaces them

- **Nude base values per class (template)**: Every starting class has base P.Atk 4 (fighters) or 3 (mystics), M.Atk 6, P.Def 80 (fighters) or 54 (mystics), M.Def 41. These are the values with nothing worn, before the level and attribute multipliers. The same numbers in all nine level-1 templates (human, elf, dark elf, orc, dwarf). Sources: github.com/DEVjEXTREME/L2jaCis-409 data/xml/classes/*.xml <set pAtk pDef mAtk mDef>, github.com/Hl4p3x/L2JServer_C6_Interlude dist/game/data/stats/playerTemplates.xml basePAtk/basePDef/baseMAtk/baseMDef, github.com/david-buzas/l2j-interlude-datapack sql/char_templates.sql P_ATK,P_DEF,M_ATK,M_DEF.
- **P.Def: empty-slot values replaced by armour**: FuncPDefMod subtracts a slot's built-in share whenever that slot holds an item, and the item's own P.Def is added instead: head 12, chest 31 (fighter) / 15 (mystic), legs 18 / 8 (also removed when a full-body armour is in the chest), gloves 8, feet 7. Then the total is multiplied by the level modifier (89 + level) / 100, i.e. 0.90 at level 1. Sum of the replaceable shares: fighter 76 of 80, mystic 50 of 54. The remaining 4 is never removed: neither codebase subtracts anything for the underwear slot (no underwear 3 or cloak 1 constant exists), so underwear/cloak items simply add on top. Formula: P.Def = (base 80|54 - shares of occupied slots + item P.Def, incl. underwear) x (89+lvl)/100. Nude level-1 P.Def shown = 72 (fighter), 48.6 (mystic). Weapon and jewellery do not touch P.Def. Order of operations: L2J C6 item 'add pDef' at order 0x10 before FuncPDefMod at 0x20; aCis item 'baseadd pDef' at order 2 before FuncPDefMod at 10, same result. Example: human fighter in Squire's Shirt (33) + Squire's Pants (20): (80-31-18+33+20) x 0.9 = 75.6. Sources: github.com/DEVjEXTREME/L2jaCis-409 skills/funcs/FuncPDefMod.java, github.com/Hl4p3x/L2JServer_C6_Interlude java/.../model/skills/Formulas.java class FuncPDefMod.
- **M.Def: empty jewellery-slot values replaced by jewellery**: FuncMDefMod subtracts each occupied jewellery slot's share: each ring 5, each earring 9, necklace 13 (5+5+9+9+13 = 41, the whole nude M.Def), and the jewel's own M.Def replaces it. Then x MEN bonus x level modifier. MEN bonus = 1.010^(MEN+0.060), rounded to 2 decimals (L2J stores it as a table in statBonus.xml, identical values). Nude level-1 M.Def: human fighter (MEN 25, x1.28) 47.2, human mystic (MEN 39, x1.48) 54.6, elf fighter/DE fighter (MEN 26, 1.30) 48.0, elf mystic (MEN 40, 1.49) 55.0, DE mystic (MEN 37, 1.45) 53.5, orc fighter (MEN 27, 1.31) 48.3, orc mystic (MEN 42, 1.52) 56.1. Sources: github.com/DEVjEXTREME/L2jaCis-409 skills/funcs/FuncMDefMod.java and skills/Formulas.java MEN_COMPUTE, github.com/Hl4p3x/L2JServer_C6_Interlude Formulas.java FuncMDefMod and dist/game/data/stats/statBonus.xml <MEN>.
- **P.Atk / M.Atk: weapon replaces the unarmed base**: A weapon's P.Atk and M.Atk are 'set' functions at the earliest order (L2J 0x08, aCis order 0), so they overwrite the template's 4/3 P.Atk and 6 M.Atk rather than adding to them. Unarmed, the class's fist template (Human Fighter Fist id 246 etc.) is the active weapon for speed (325) and crit (4) but is not an equipped item, so the template P.Atk 4 (fighter) / 3 (mystic) and M.Atk 6 stand. Then P.Atk x STR bonus x level mod; M.Atk x (INT bonus)^2 x (level mod)^2. STR bonus = 1.036^(STR-34.845), INT bonus = 1.020^(INT-31.375), both rounded to 2 decimals. Nude level-1 P.Atk: human fighter 4 x 1.20 x 0.9 = 4.3; human mystic 3 x 0.63 x 0.9 = 1.7. With Squire's Sword (P.Atk 6): 6 x 1.20 x 0.9 = 6.5. Sources: github.com/DEVjEXTREME/L2jaCis-409 skills/funcs/FuncPAtkMod.java, FuncMAtkMod.java, skills/basefuncs/FuncSet.java (order 0), github.com/Hl4p3x/L2JServer_C6_Interlude Formulas.java FuncPAtkMod/FuncMAtkMod; items/2300-2399.xml Squire's Sword <set order="0x08" stat="pAtk">.

## The inventory

- **Inventory slot limit**: 80 slots for every race except dwarves (100), configurable server setting with those defaults. A slot is one inventory entry: a stackable item (adena, potions, arrows, shots, scrolls) takes one slot however many you hold, and adding more of a stackable you already carry takes 0 new slots; each non-stackable item (each weapon, armour piece, jewel) takes its own slot. Equipped items still count (they stay in the inventory list). Sources: github.com/DEVjEXTREME/L2jaCis-409 Config.java MaximumSlotsForNoDwarf=80/ForDwarf=100; PcInventory.calculateUsedSlots/validateCapacity, github.com/Hl4p3x/L2JServer_C6_Interlude Config.java + dist/game/config/main/Character.ini MaximumSlotsForNoDwarf = 80; PlayerInventory.validateCapacity.
- **Weight limit and weight penalty**: Weight matters. Limit = 69000 x CON bonus (CON bonus = 1.030^(CON-27.632), 2 decimals), times a server multiplier of 1. Load is the sum of item weights x count (adena weighs 0; Soulshot 4, Lesser Healing Potion 5, Wooden Arrow 6, Scroll of Escape 120 each; Squire's Sword 1600, Squire's Shirt 3301, a ring/necklace 150). Penalty tiers by load/limit: under 50% none; 50-66.6% level 1 (aCis: regen x0.5); 66.6-80% level 2 (speed x0.5, regen x0.5); 80-100% level 3 (same); 100%+ level 4 (cannot move, regen x0.1); you cannot pick up/buy past 100%. L2J C6 clamps CON<1 to 31000 and CON>59 to 176000. Level-1 limits: human fighter (CON 43) 109,020; human mystic (27) 67,620; elf fighter (36) 88,320; elf mystic (25) 64,170; DE fighter (32) 78,660; DE mystic (24) 62,100; orc fighter (47) 122,130; orc mystic (31) 75,900; dwarf fighter (45) 115,230. Sources: github.com/DEVjEXTREME/L2jaCis-409 Player.getWeightLimit/refreshWeightPenalty, enums/actors/WeightPenalty.java, github.com/Hl4p3x/L2JServer_C6_Interlude PlayerInstance.getMaxLoad/refreshOverloaded.

## No-grade jewellery

- **No-grade jewellery sold in the starting villages**: Necklaces: Necklace of Magic M.Def 15 (66 ref), Necklace of Knowledge 18 (1,080), Necklace of Anguish 21 (4,680), Necklace of Wisdom 25 (11,900). Earrings: Apprentice's Earring 11 (49), Mystic's Earring 13 (811), Earring of Strength 16 (3,510), Earring of Wisdom 16 (3,510), Cat's Eye Earring 19 (8,890). Rings: Magic Ring 7 (33), Ring of Knowledge 9 (540), Ring of Anguish 11 (2,340), Ring of Wisdom 12 (5,920). Each weighs 150. Every one beats its empty-slot share (necklace 13, earring 9, ring 5); a full set of the cheapest (15+11+11+7+7 = 51) replaces the nude 41. Sources: github.com/DEVjEXTREME/L2jaCis-409 data/xml/items/*.xml mDef + buyLists.xml list 13, github.com/Hl4p3x/L2JServer_C6_Interlude dist/game/data/stats/items/*.xml, l2hub.info/il/items/necklace_of_magic (M Def 15, price 66), /items/magic_ring (M Def 7, price 33).

**No-grade jewellery sold in the starting villages: items**

| id | name | kind | ref_price | shop_price_15pct_tax | slot | grade | weight | m_def |
|---|---|---|---|---|---|---|---|---|
| 118 | Necklace of Magic | jewellery | 66 | 75 | necklace | none | 150 | 15 |
| 906 | Necklace of Knowledge | jewellery | 1080 | 1242 | necklace | none | 150 | 18 |
| 907 | Necklace of Anguish | jewellery | 4680 | 5382 | necklace | none | 150 | 21 |
| 908 | Necklace of Wisdom | jewellery | 11900 | 13685 | necklace | none | 150 | 25 |
| 112 | Apprentice's Earring | jewellery | 49 | 56 | earring | none | 150 | 11 |
| 113 | Mystic's Earring | jewellery | 811 | 932 | earring | none | 150 | 13 |
| 114 | Earring of Strength | jewellery | 3510 | 4036 | earring | none | 150 | 16 |
| 115 | Earring of Wisdom | jewellery | 3510 | 4036 | earring | none | 150 | 16 |
| 845 | Cat's Eye Earring | jewellery | 8890 | 10223 | earring | none | 150 | 19 |
| 116 | Magic Ring | jewellery | 33 | 37 | ring | none | 150 | 7 |
| 875 | Ring of Knowledge | jewellery | 540 | 621 | ring | none | 150 | 9 |
| 876 | Ring of Anguish | jewellery | 2340 | 2691 | ring | none | 150 | 11 |
| 877 | Ring of Wisdom | jewellery | 5920 | 6808 | ring | none | 150 | 12 |

## Shields

- **No-grade shields sold in the starting villages**: Four, on the armour trader's fighter and mystic lists alike: Leather Shield, Small Shield, Buckler and Round Shield. Every one blocks at rate 20 and takes 8 off Evasion, and they differ only in shield defence (Sh.Def), weight and price. The rate and the Evasion are the same on every shield in the game, all 95 in both codebases from the Leather Shield to the S-grade ones, so a better shield never blocks more often, only harder, and wearing any shield costs the same 8 Evasion. aCis writes each as `sub rEvas 8`, `set rShld 20`, `set sDef`; L2J C6 as the same three functions plus `avoid_modify -8`, `shield_def` and `shield_def_rate`, and the two agree item for item. Sources: github.com/DEVjEXTREME/L2jaCis-409 aCis_datapack/data/xml/items/0000-0099.xml (ids 18-20) and 0100-0199.xml (102), every items/*.xml for the 95; github.com/Hl4p3x/L2JServer_C6_Interlude dist/game/data/stats/items/0000-0099.xml and 0100-0199.xml, every stats/items/*.xml for the 95.
- **Blocking a blow**: Both cores roll a block only against a physical blow, and only with a shield in the left hand: chance % = the SHIELD_RATE stat (the shield's rate) × the DEX bonus. A block adds the shield's Sh.Def to P.Def for that blow; a perfect block takes the blow to 1 damage. aCis (Formulas.calcShldUse): only against an attacker within 120° in front; the chance ×3 against a bow and ×3 on a critical; one roll of 0-99 decides both outcomes, below PerfectShieldBlockRate (5) a perfect block and below the chance a block, so 5 blows in 100 are perfect whatever the shield. L2J C6 (Formulas.calcShldUse, calcPhysDam): only from the front unless the defender has Aegis (316) or Aegis Stance (318); the chance ×1.3 against a bow; a perfect block is a second roll after a block succeeds, (100 - AltPerfectShieldBlockRate 5) < Rnd(100), so about 1 block in 25 is perfect. AltShieldBlocks = False, so a block adds Sh.Def to P.Def rather than subtracting it from the damage. Sources: github.com/DEVjEXTREME/L2jaCis-409 aCis_gameserver/java/net/sf/l2j/gameserver/skills/Formulas.java and config/players.properties, github.com/Hl4p3x/L2JServer_C6_Interlude java/org/l2jserver/gameserver/model/skills/Formulas.java and dist/game/config/main/Character.ini.

**No-grade shields sold in the starting villages: items**

| id | name | kind | ref_price | shop_price_15pct_tax | slot | grade | weight | sh_def | block_rate | evasion |
|---|---|---|---|---|---|---|---|---|---|---|
| 18 | Leather Shield | shield | 39 | 44 | lhand | none | 1430 | 47 | 20 | -8 |
| 19 | Small Shield | shield | 638 | 733 | lhand | none | 1420 | 56 | 20 | -8 |
| 20 | Buckler | shield | 2780 | 3197 | lhand | none | 1410 | 67 | 20 | -8 |
| 102 | Round Shield | shield | 7110 | 8176 | lhand | none | 1390 | 79 | 20 | -8 |

## The village shops

- **Talking Island Village traders**: Four traders. Weapon trader: a fighter list (no-grade swords, blunts, daggers, bows, Brandish, Short Spear, Zweihander; 768 to 244,000 reference) and a mystic list (Apprentice's Rod to Journeyman's Staff). Armour trader: fighter list (light shirts/pants/breastplates/gaiters plus shields, gloves, shoes, caps/helmets) and mystic list (tunics/stockings plus the same shields, gloves, shoes, helmets). Accessory trader: 4 necklaces, 5 earrings, 4 rings (no-grade) and a spellbook list. Grocer: shots, arrows, Lesser Healing Potion, Antidote, Bandage, Haste/Alacrity potions, Scroll of Escape, Scroll of Resurrection, elixirs, ores, Thief Key, dice. Lists are item-for-item and price-for-price identical to the other three villages, except Orc Village's extra fist weapons and amulets. ref_price is the item's reference price; shop_price_15pct_tax is what the shop charges at the default 15% tax (both aCis and l2hub). No item here is above no-grade except Bone Arrow and the D-grade elixirs/scroll. Sources: github.com/DEVjEXTREME/L2jaCis-409 data/xml/buyLists.xml (+ npcs/*.xml, spawnlist/*.xml for location), github.com/Hl4p3x/L2JServer_C6_Interlude dist/db_installer/sql/install/merchant_buylists.sql + merchant_shopids.sql, github.com/david-buzas/l2j-interlude-datapack sql/merchant_buylists.sql (identical items to L2J), l2hub.info/il/npcs/<trader> merchant sellLists (tax 15, defaultPrice).
- **Elven Village traders**: Four traders. Weapon trader: a fighter list (no-grade swords, blunts, daggers, bows, Brandish, Short Spear, Zweihander; 768 to 244,000 reference) and a mystic list (Apprentice's Rod to Journeyman's Staff). Armour trader: fighter list (light shirts/pants/breastplates/gaiters plus shields, gloves, shoes, caps/helmets) and mystic list (tunics/stockings plus the same shields, gloves, shoes, helmets). Accessory trader: 4 necklaces, 5 earrings, 4 rings (no-grade) and a spellbook list. Grocer: shots, arrows, Lesser Healing Potion, Antidote, Bandage, Haste/Alacrity potions, Scroll of Escape, Scroll of Resurrection, elixirs, ores, Thief Key, dice. Lists are item-for-item and price-for-price identical to the other three villages, except Orc Village's extra fist weapons and amulets. ref_price is the item's reference price; shop_price_15pct_tax is what the shop charges at the default 15% tax (both aCis and l2hub). No item here is above no-grade except Bone Arrow and the D-grade elixirs/scroll. Sources: github.com/DEVjEXTREME/L2jaCis-409 data/xml/buyLists.xml (+ npcs/*.xml, spawnlist/*.xml for location), github.com/Hl4p3x/L2JServer_C6_Interlude dist/db_installer/sql/install/merchant_buylists.sql + merchant_shopids.sql, github.com/david-buzas/l2j-interlude-datapack sql/merchant_buylists.sql (identical items to L2J), l2hub.info/il/npcs/<trader> merchant sellLists (tax 15, defaultPrice).
- **Dark Elf Village traders**: Four traders. Weapon trader: a fighter list (no-grade swords, blunts, daggers, bows, Brandish, Short Spear, Zweihander; 768 to 244,000 reference) and a mystic list (Apprentice's Rod to Journeyman's Staff). Armour trader: fighter list (light shirts/pants/breastplates/gaiters plus shields, gloves, shoes, caps/helmets) and mystic list (tunics/stockings plus the same shields, gloves, shoes, helmets). Accessory trader: 4 necklaces, 5 earrings, 4 rings (no-grade) and a spellbook list. Grocer: shots, arrows, Lesser Healing Potion, Antidote, Bandage, Haste/Alacrity potions, Scroll of Escape, Scroll of Resurrection, elixirs, ores, Thief Key, dice. Lists are item-for-item and price-for-price identical to the other three villages, except Orc Village's extra fist weapons and amulets. ref_price is the item's reference price; shop_price_15pct_tax is what the shop charges at the default 15% tax (both aCis and l2hub). No item here is above no-grade except Bone Arrow and the D-grade elixirs/scroll. Sources: github.com/DEVjEXTREME/L2jaCis-409 data/xml/buyLists.xml (+ npcs/*.xml, spawnlist/*.xml for location), github.com/Hl4p3x/L2JServer_C6_Interlude dist/db_installer/sql/install/merchant_buylists.sql + merchant_shopids.sql, github.com/david-buzas/l2j-interlude-datapack sql/merchant_buylists.sql (identical items to L2J), l2hub.info/il/npcs/<trader> merchant sellLists (tax 15, defaultPrice).
- **Orc Village traders**: Four traders. Weapon trader: a fighter list (no-grade swords, blunts, daggers, bows, Brandish, Short Spear, Zweihander; 768 to 244,000 reference) and a mystic list (Apprentice's Rod to Journeyman's Staff). Armour trader: fighter list (light shirts/pants/breastplates/gaiters plus shields, gloves, shoes, caps/helmets) and mystic list (tunics/stockings plus the same shields, gloves, shoes, helmets). Accessory trader: 4 necklaces, 5 earrings, 4 rings (no-grade) and a spellbook list. Grocer: shots, arrows, Lesser Healing Potion, Antidote, Bandage, Haste/Alacrity potions, Scroll of Escape, Scroll of Resurrection, elixirs, ores, Thief Key, dice. Jakal's fighter list adds four fist weapons (dual fists, two-handed): Spiked Gloves, Iron Gloves, Fox Claw Gloves, Cestus; Uska sells orc amulets instead of spellbooks. ref_price is the item's reference price; shop_price_15pct_tax is what the shop charges at the default 15% tax (both aCis and l2hub). No item here is above no-grade except Bone Arrow and the D-grade elixirs/scroll. Sources: github.com/DEVjEXTREME/L2jaCis-409 data/xml/buyLists.xml (+ npcs/*.xml, spawnlist/*.xml for location), github.com/Hl4p3x/L2JServer_C6_Interlude dist/db_installer/sql/install/merchant_buylists.sql + merchant_shopids.sql, github.com/david-buzas/l2j-interlude-datapack sql/merchant_buylists.sql (identical items to L2J), l2hub.info/il/npcs/<trader> merchant sellLists (tax 15, defaultPrice).
- **What is common vs village-only**: Weapons (fighter 23, mystic 7), armour (fighter 30, mystic 29), jewellery (13) and grocer (37) lists are identical in all four villages, same items, order and prices. Only Orc Village's weapon trader Jakal adds Spiked Gloves (768 ref, P.Atk 10), Iron Gloves (12,500, P.Atk 13), Fox Claw Gloves (54,100, P.Atk 21), Cestus (136,000, P.Atk 29), all two-handed dual fists at 325 attack speed. Among the four starting villages only Jakal sells fists, although l2hub shows Cestus in 15 shops elsewhere (Gludin, Gludio, Dion, etc.). The second list of the accessory trader is spellbooks (35) in TI, Elven and Dark Elf villages, but orc amulets (13) in Orc Village. Each village also has a Spellbook Seller (Antonio, Lynn, Triya; Shantra 'Amulet Seller' in Orc Village) duplicating that list, and a Fishing Guild Member. Sources: github.com/DEVjEXTREME/L2jaCis-409 buyLists.xml, github.com/Hl4p3x/L2JServer_C6_Interlude merchant_buylists.sql, l2hub.info/il/items/cestus/shops.

**Lector, Trader: weapons (fighter list, mystic list): the fighter list**

| Item | Kind | Slot | Grade | P.Atk | M.Atk | P.Def | M.Def | Reference | Shop |
|---|---|---|---|---|---|---|---|---|---|
| Short Sword | weapon | one-handed | none | 8 | 6 |  |  | 768 | 883 |
| Club | weapon | one-handed | none | 8 | 6 |  |  | 768 | 883 |
| Bone Dagger | weapon | one-handed | none | 7 | 6 |  |  | 768 | 883 |
| Short Bow | weapon | two-handed | none | 16 | 6 |  |  | 768 | 883 |
| Broadsword | weapon | one-handed | none | 11 | 9 |  |  | 12500 | 14375 |
| Heavy Chisel | weapon | one-handed | none | 10 | 8 |  |  | 8070 | 9280 |
| Knife | weapon | one-handed | none | 10 | 9 |  |  | 12500 | 14375 |
| Doom Dagger | weapon | one-handed | none | 10 | 9 |  |  | 12500 | 14375 |
| Bow | weapon | two-handed | none | 23 | 9 |  |  | 12500 | 14375 |
| Mace | weapon | one-handed | none | 11 | 9 |  |  | 12500 | 14375 |
| Sickle | weapon | one-handed | none | 12 | 9 |  |  | 18500 | 21275 |
| Brandish | weapon | two-handed | none | 21 | 12 |  |  | 54100 | 62215 |
| Gladius | weapon | one-handed | none | 17 | 12 |  |  | 54100 | 62215 |
| Orcish Sword | weapon | one-handed | none | 17 | 12 |  |  | 54100 | 62215 |
| Handmade Sword | weapon | one-handed | none | 17 | 12 |  |  | 54100 | 62215 |
| Dwarven Mace | weapon | one-handed | none | 17 | 12 |  |  | 54100 | 62215 |
| Dirk | weapon | one-handed | none | 15 | 12 |  |  | 54100 | 62215 |
| Hunting Bow | weapon | two-handed | none | 34 | 12 |  |  | 54100 | 62215 |
| Long Sword | weapon | one-handed | none | 24 | 17 |  |  | 136000 | 156400 |
| Throwing Knife | weapon | one-handed | none | 21 | 17 |  |  | 136000 | 156400 |
| Forest Bow | weapon | two-handed | none | 49 | 17 |  |  | 136000 | 156400 |
| Short Spear | weapon | two-handed | none | 24 | 17 |  |  | 136000 | 156400 |
| Zweihander | weapon | two-handed | none | 38 | 21 |  |  | 244000 | 280600 |

**Lector, Trader: weapons (fighter list, mystic list): the mystic list**

| Item | Kind | Slot | Grade | P.Atk | M.Atk | P.Def | M.Def | Reference | Shop |
|---|---|---|---|---|---|---|---|---|---|
| Apprentice's Rod | weapon | one-handed | none | 6 | 8 |  |  | 768 | 883 |
| Buffalo's Horn | weapon | one-handed | none | 6 | 8 |  |  | 768 | 883 |
| Willow Staff | weapon | two-handed | none | 11 | 12 |  |  | 12500 | 14375 |
| Apprentice's Spellbook | weapon | one-handed | none | 9 | 12 |  |  | 12500 | 14375 |
| Cedar Staff | weapon | two-handed | none | 16 | 16 |  |  | 54100 | 62215 |
| Journeyman's Staff | weapon | two-handed | none | 23 | 22 |  |  | 136000 | 156400 |
| Relic of The Saints | weapon | one-handed | none | 19 | 22 |  |  | 136000 | 156400 |

**Jackson, Trader: armour and shields (fighter list, mystic list): the fighter list**

| Item | Kind | Slot | Grade | P.Atk | M.Atk | P.Def | M.Def | Reference | Shop |
|---|---|---|---|---|---|---|---|---|---|
| Pants | armour | legs | none |  |  | 22 |  | 92 | 105 |
| Shirt | armour | chest | none |  |  | 36 |  | 147 | 169 |
| Leather Pants | armour | legs | none |  |  | 27 |  | 1520 | 1748 |
| Leather Shirt | armour | chest | none |  |  | 43 |  | 2430 | 2794 |
| Hard Leather Pants | armour | legs | none |  |  | 29 |  | 4970 | 5715 |
| Wooden Gaiters | armour | legs | none |  |  | 29 |  | 4970 | 5715 |
| Wooden Breastplate | armour | chest | none |  |  | 47 |  | 7960 | 9154 |
| Cotton Pants | armour | legs | none |  |  | 32 |  | 12700 | 14605 |
| Cotton Shirt | armour | chest | none |  |  | 50 |  | 20300 | 23345 |
| Bone Breastplate | armour | chest | none |  |  | 50 |  | 20300 | 23345 |
| Bone Gaiters | armour | legs | none |  |  | 32 |  | 12700 | 14605 |
| Leather Shield | shield | shield | none |  |  |  |  | 39 | 44 |
| Small Shield | shield | shield | none |  |  |  |  | 638 | 733 |
| Buckler | shield | shield | none |  |  |  |  | 2780 | 3197 |
| Round Shield | shield | shield | none |  |  |  |  | 7110 | 8176 |
| Short Gloves | armour | gloves | none |  |  | 9 |  | 37 | 42 |
| Short Leather Gloves | armour | gloves | none |  |  | 11 |  | 607 | 698 |
| Gloves | armour | gloves | none |  |  | 13 |  | 2650 | 3047 |
| Leather Gloves | armour | gloves | none |  |  | 15 |  | 6770 | 7785 |
| Apprentice's Shoes | armour | feet | none |  |  | 8 |  | 7 | 8 |
| Cloth Shoes | armour | feet | none |  |  | 9 |  | 37 | 42 |
| Leather Sandals | armour | feet | none |  |  | 9 |  | 37 | 42 |
| Crude Leather Shoes | armour | feet | none |  |  | 11 |  | 607 | 698 |
| Cotton Shoes | armour | feet | none |  |  | 11 |  | 607 | 698 |
| Leather Shoes | armour | feet | none |  |  | 13 |  | 2650 | 3047 |
| Low Boots | armour | feet | none |  |  | 15 |  | 6770 | 7785 |
| Cloth Cap | armour | head | none |  |  | 13 |  | 55 | 63 |
| Leather Cap | armour | head | none |  |  | 16 |  | 911 | 1047 |
| Wooden Helmet | armour | head | none |  |  | 19 |  | 3980 | 4577 |
| Leather Helmet | armour | head | none |  |  | 23 |  | 10200 | 11730 |

**Jackson, Trader: armour and shields (fighter list, mystic list): the mystic list**

| Item | Kind | Slot | Grade | P.Atk | M.Atk | P.Def | M.Def | Reference | Shop |
|---|---|---|---|---|---|---|---|---|---|
| Stockings | armour | legs | none |  |  | 11 |  | 92 | 105 |
| Tunic | armour | chest | none |  |  | 18 |  | 147 | 169 |
| Cotton Stockings | armour | legs | none |  |  | 13 |  | 1520 | 1748 |
| Cotton Tunic | armour | chest | none |  |  | 21 |  | 2430 | 2794 |
| Feriotic Stockings | armour | legs | none |  |  | 13 |  | 1520 | 1748 |
| Feriotic Tunic | armour | chest | none |  |  | 21 |  | 2430 | 2794 |
| Leather Stockings | armour | legs | none |  |  | 16 |  | 4970 | 5715 |
| Leather Tunic | armour | chest | none |  |  | 25 |  | 7960 | 9154 |
| Stockings of Devotion | armour | legs | none |  |  | 19 |  | 12700 | 14605 |
| Tunic of Devotion | armour | chest | none |  |  | 30 |  | 20300 | 23345 |
| Leather Shield | shield | shield | none |  |  |  |  | 39 | 44 |
| Small Shield | shield | shield | none |  |  |  |  | 638 | 733 |
| Buckler | shield | shield | none |  |  |  |  | 2780 | 3197 |
| Round Shield | shield | shield | none |  |  |  |  | 7110 | 8176 |
| Short Gloves | armour | gloves | none |  |  | 9 |  | 37 | 42 |
| Short Leather Gloves | armour | gloves | none |  |  | 11 |  | 607 | 698 |
| Gloves | armour | gloves | none |  |  | 13 |  | 2650 | 3047 |
| Leather Gloves | armour | gloves | none |  |  | 15 |  | 6770 | 7785 |
| Apprentice's Shoes | armour | feet | none |  |  | 8 |  | 7 | 8 |
| Cloth Shoes | armour | feet | none |  |  | 9 |  | 37 | 42 |
| Leather Sandals | armour | feet | none |  |  | 9 |  | 37 | 42 |
| Crude Leather Shoes | armour | feet | none |  |  | 11 |  | 607 | 698 |
| Cotton Shoes | armour | feet | none |  |  | 11 |  | 607 | 698 |
| Leather Shoes | armour | feet | none |  |  | 13 |  | 2650 | 3047 |
| Low Boots | armour | feet | none |  |  | 15 |  | 6770 | 7785 |
| Cloth Cap | armour | head | none |  |  | 13 |  | 55 | 63 |
| Leather Cap | armour | head | none |  |  | 16 |  | 911 | 1047 |
| Wooden Helmet | armour | head | none |  |  | 19 |  | 3980 | 4577 |
| Leather Helmet | armour | head | none |  |  | 23 |  | 10200 | 11730 |

**Silvia, Trader: accessories (jewellery) and spellbooks: the accessories list**

| Item | Kind | Slot | Grade | P.Atk | M.Atk | P.Def | M.Def | Reference | Shop |
|---|---|---|---|---|---|---|---|---|---|
| Necklace of Magic | jewellery | necklace | none |  |  |  | 15 | 66 | 75 |
| Necklace of Knowledge | jewellery | necklace | none |  |  |  | 18 | 1080 | 1242 |
| Necklace of Anguish | jewellery | necklace | none |  |  |  | 21 | 4680 | 5382 |
| Necklace of Wisdom | jewellery | necklace | none |  |  |  | 25 | 11900 | 13685 |
| Apprentice's Earring | jewellery | earring | none |  |  |  | 11 | 49 | 56 |
| Mystic's Earring | jewellery | earring | none |  |  |  | 13 | 811 | 932 |
| Earring of Strength | jewellery | earring | none |  |  |  | 16 | 3510 | 4036 |
| Earring of Wisdom | jewellery | earring | none |  |  |  | 16 | 3510 | 4036 |
| Cat's Eye Earring | jewellery | earring | none |  |  |  | 19 | 8890 | 10223 |
| Magic Ring | jewellery | ring | none |  |  |  | 7 | 33 | 37 |
| Ring of Knowledge | jewellery | ring | none |  |  |  | 9 | 540 | 621 |
| Ring of Anguish | jewellery | ring | none |  |  |  | 11 | 2340 | 2691 |
| Ring of Wisdom | jewellery | ring | none |  |  |  | 12 | 5920 | 6808 |

**Silvia, Trader: accessories (jewellery) and spellbooks: the spellbooks list**

| Item | Kind | Slot | Grade | P.Atk | M.Atk | P.Def | M.Def | Reference | Shop |
|---|---|---|---|---|---|---|---|---|---|
| Spellbook: Defense Aura |  |  |  |  |  |  |  | 75 | 86 |
| Spellbook: Attack Aura |  |  |  |  |  |  |  | 75 | 86 |
| Spellbook: Might |  |  |  |  |  |  |  | 100 | 115 |
| Spellbook: Battle Heal |  |  |  |  |  |  |  | 100 | 115 |
| Spellbook: Vampiric Touch |  |  |  |  |  |  |  | 100 | 115 |
| Spellbook: Ice Bolt |  |  |  |  |  |  |  | 100 | 115 |
| Spellbook: Heal |  |  |  |  |  |  |  | 100 | 115 |
| Spellbook: Group Heal |  |  |  |  |  |  |  | 500 | 575 |
| Spellbook: Shield |  |  |  |  |  |  |  | 500 | 575 |
| Spellbook: Wind Shackle |  |  |  |  |  |  |  | 500 | 575 |
| Spellbook: Wind Walk |  |  |  |  |  |  |  | 500 | 575 |
| Spellbook: Curse: Weakness |  |  |  |  |  |  |  | 500 | 575 |
| Spellbook: Curse: Poison |  |  |  |  |  |  |  | 500 | 575 |
| Spellbook: Cure Poison |  |  |  |  |  |  |  | 500 | 575 |
| Spellbook: Flame Strike |  |  |  |  |  |  |  | 500 | 575 |
| Spellbook: Drain Health |  |  |  |  |  |  |  | 550 | 633 |
| Spellbook: Elemental Heal |  |  |  |  |  |  |  | 550 | 633 |
| Spellbook: Disrupt Undead |  |  |  |  |  |  |  | 750 | 863 |
| Spellbook: Resurrection |  |  |  |  |  |  |  | 800 | 920 |
| Spellbook: Blaze |  |  |  |  |  |  |  | 750 | 863 |
| Spellbook: Summon Shadow |  |  |  |  |  |  |  | 800 | 920 |
| Spellbook: Summon Silhouette |  |  |  |  |  |  |  | 800 | 920 |
| Spellbook: Summon Boxer the Unicorn |  |  |  |  |  |  |  | 800 | 920 |
| Spellbook: Summon Kat the Cat |  |  |  |  |  |  |  | 750 | 863 |
| Spellbook: Servitor Heal |  |  |  |  |  |  |  | 750 | 863 |
| Spellbook: Aqua Swirl |  |  |  |  |  |  |  | 750 | 863 |
| Spellbook: Acumen |  |  |  |  |  |  |  | 750 | 863 |
| Spellbook: Energy Bolt |  |  |  |  |  |  |  | 900 | 1035 |
| Spellbook: Aura Burn |  |  |  |  |  |  |  | 750 | 863 |
| Spellbook: Charm |  |  |  |  |  |  |  | 800 | 920 |
| Spellbook: Concentration |  |  |  |  |  |  |  | 750 | 863 |
| Spellbook: Kiss of Eva |  |  |  |  |  |  |  | 800 | 920 |
| Spellbook: Twister |  |  |  |  |  |  |  | 750 | 863 |
| Spellbook: Poison |  |  |  |  |  |  |  | 750 | 863 |
| Spellbook: Poison Recovery |  |  |  |  |  |  |  | 750 | 863 |

**Katerina, Trader: consumables and minerals (grocer): the consumables list**

| Item | Kind | Slot | Grade | P.Atk | M.Atk | P.Def | M.Def | Reference | Shop |
|---|---|---|---|---|---|---|---|---|---|
| Soulshot: No Grade | consumable |  |  |  |  |  |  | 7 | 8 |
| Spiritshot: No Grade | consumable |  |  |  |  |  |  | 15 | 17 |
| Blessed Spiritshot: No Grade | consumable |  |  |  |  |  |  | 35 | 40 |
| Compressed Package of Blessed Spiritshots: No Grade | consumable |  |  |  |  |  |  | 11550 | 13282 |
| Compressed Package of Spiritshots: No Grade | consumable |  |  |  |  |  |  | 4950 | 5692 |
| Compressed Package of Soulshots: No Grade | consumable |  |  |  |  |  |  | 2300 | 2645 |
| Greater Compressed Package of Blessed Spiritshots: No-grade | consumable |  |  |  |  |  |  | 38500 | 44275 |
| Greater Compressed Package of Spiritshots: No-grade | consumable |  |  |  |  |  |  | 16500 | 18975 |
| Greater Compressed Package of Soulshots: No-grade | consumable |  |  |  |  |  |  | 7700 | 8855 |
| Wooden Arrow | consumable |  |  |  |  |  |  | 2 | 2 |
| Bone Arrow | consumable |  |  |  |  |  |  | 3 | 3 |
| Lesser Healing Potion | consumable |  |  |  |  |  |  | 90 | 103 |
| Antidote | consumable |  |  |  |  |  |  | 75 | 86 |
| Bandage | consumable |  |  |  |  |  |  | 75 | 86 |
| Haste Potion | consumable |  |  |  |  |  |  | 1200 | 1380 |
| Potion of Alacrity | consumable |  |  |  |  |  |  | 2400 | 2760 |
| Magic Haste Potion | consumable |  |  |  |  |  |  | 2400 | 2760 |
| Scroll of Escape | consumable |  |  |  |  |  |  | 400 | 460 |
| Scroll of Resurrection | consumable |  |  |  |  |  |  | 2000 | 2300 |
| Spirit Ore | consumable |  |  |  |  |  |  | 400 | 460 |
| Soul Ore | consumable |  |  |  |  |  |  | 250 | 288 |
| Energy Stone | consumable |  |  |  |  |  |  | 100 | 115 |
| Thief Key | consumable |  |  |  |  |  |  | 1000 | 1150 |
| Rope of Magic: D-Grade | consumable |  |  |  |  |  |  | 100 | 115 |
| Scroll: Recovery (No Grade) | consumable |  |  |  |  |  |  | 2000 | 2300 |
| Scroll: Recovery (Grade D) | consumable |  |  |  |  |  |  | 4800 | 5520 |
| Elixir of Life (No Grade) | consumable |  |  |  |  |  |  | 1300 | 1495 |
| Elixir of Life (D-Grade) | consumable |  |  |  |  |  |  | 3450 | 3967 |
| Elixir of Mental Strength (No Grade) | consumable |  |  |  |  |  |  | 1200 | 1380 |
| Elixir of Mental Strength (D-Grade) | consumable |  |  |  |  |  |  | 3400 | 3910 |
| Elixir of CP (No Grade) | consumable |  |  |  |  |  |  | 600 | 690 |
| Elixir of CP (D-Grade) | consumable |  |  |  |  |  |  | 1400 | 1610 |
| Summoning Crystal | consumable |  |  |  |  |  |  | 35000 | 40250 |
| Dice (Heart) | consumable |  |  |  |  |  |  | 500 | 575 |
| Dice (Spade) | consumable |  |  |  |  |  |  | 500 | 575 |
| Dice (Clover) | consumable |  |  |  |  |  |  | 500 | 575 |
| Dice (Diamond) | consumable |  |  |  |  |  |  | 500 | 575 |

## Disputes and caveats

What the checks could not settle, kept as the checker wrote it.

- Shop prices: aCis buylists store reference price x 1.15 exactly (the default 15% castle tax), and l2hub shows tax:15 with defaultPrice equal to the item reference price, so the two agree. L2J C6 (and david-buzas) buylists hold different, mostly ~0.96 x reference numbers (e.g. Short Sword 739 vs reference 768, aCis 883); treat those as non-retail. Item reference prices are identical in aCis and L2J C6 item templates.
- One disagreement: Elixir of Mental Strength (No Grade) (8628) is 1,200 reference in aCis and L2J C6 templates but 1,400 on l2hub; L2J's buylist price 1,348 (~0.963 x 1,400) suggests 1,400.
- Spellbook lists (TI/Elven/DE accessory trader second list) disagree: l2hub shows 34-92 books including later-level ones and lacks Curse: Weakness/Curse: Poison, and lists several at 800 where aCis/L2J say 750 (Energy Bolt 900). Orc amulet list also longer on l2hub. Not needed for weapons/armour/jewellery/consumables, kept in data with aCis values only.
- The nude P.Def residual of 4 (80-76, 54-50) is not attributed to any slot in either codebase; the 'underwear 3' figure in the brief does not appear in code. No cloak/back item exists in Interlude; cloaks are underwear-slot items.
- Unarmed P.Atk 4/3 is inferred from the stat pipeline: the fist template is not an equipped item, so its funcs (L2J sets pAtk 0) are not attached. Not observed in a live client.
- david-buzas char_templates.sql carries an old _LOAD column (e.g. human fighter 81,900) that neither current codebase uses; both compute 69000 x CON bonus (109,020).
- l2hub NPC slugs differ from names (Katerina=katrine, Unoren=uno, Creamees=cel, Herbiel=green, Payne=paint, Minaless=mina, Jakal=trader_jakaron).
- Shield stats (Sh.Def, block rate 20, Evasion -8) agree in aCis and L2J C6 item data (see Shields). Wooden Breastplate and Tunic of Devotion (+67 max MP) agree across both.
