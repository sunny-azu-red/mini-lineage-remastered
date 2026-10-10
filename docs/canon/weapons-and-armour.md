# Weapons and armour

Part of the Lineage II canon (Interlude, C6): the reference the game takes names and numbers from.
It is not a roadmap. Read [README.md](README.md) before using an entry.

Every weapon and armour piece by grade and type, with P.Atk, M.Atk or P.Def, the reference price, and the shops that sell it. V and T, used in the shop lists, are defined under How this was checked.

## How this was checked

- **Source key (read first)**: Fact-check pass. Every weapon and armour entry below was re-checked against l2hub.info's Interlude database (https://l2hub.info/il/items/...), which the first researcher did not use. It is PTS/client-derived: it keys items by retail internal names such as shrnoen's_breastplate and worldtree's_branch, and it lists each item's NPC shops with town names. Stats and grades were also re-read from the L2J C6 XML and from a second L2J Interlude datapack (l2j-interlude-datapack: char_templates.sql, merchant_buylists.sql, merchant_shopids.sql). l2db.ru was spot-checked. l2hub agreed with the researcher's name, grade, P.Atk, M.Atk and P.Def on every listed item except the ones flagged below. Price is the reference price; NPC shops add castle tax on top (l2hub shows Long Sword at 149,600 in Giran, 156,400 in the villages, 163,200 in most towns and 176,800 in Hunter Village). Abbreviations: V = Talking Island Village, Elven Village, Dark Elven Village, Orc Village, Dwarven Village. T = Gludin Village, Town of Gludio, Town of Dion, Town of Giran, Town of Oren, Hunters Village, Town of Aden, Heine, Town of Goddard, Rune Township, Town of Schuttgart. G5 = Giran, Heine, Goddard, Rune, Schuttgart. l2hub leaves the town blank for Rune's traders Drumond, Nils, Vladimir and Alisha (L2J npc 31300-31303, the Rune traders). Sources: [l2hub.info](https://l2hub.info/il/items/long_sword/shops), [github:Hl4p3x/L2JServer_C6_Interlude](https://github.com/Hl4p3x/L2JServer_C6_Interlude/tree/master/dist/game/data/stats/items), [l2db.ru](https://l2db.ru/items/weapons/sword/interlude).

## Where each grade is sold

- **No-grade weapons: where sold**: Confirmed by l2hub shop tabs. V only: Short Sword, Broadsword, Gladius, Orcish Sword, Handmade Sword, Brandish, Club, Mace, Heavy Chisel (8,070), Sickle (18,500), Dwarven Mace, Apprentice's Rod, Willow Staff, Cedar Staff, Bone Dagger, Knife, Doom Dagger, Dirk, Short Bow, Bow, Hunting Bow. Every V and T town: Long Sword, Throwing Knife, Forest Bow, Short Spear and Journeyman's Staff (the staff is also sold at Ivory Tower). T only (244,000 tier): Falchion, Iron Hammer, Buzdygan, Sword Breaker, Composition Bow, Long Spear, and Mage Staff (also at Ivory Tower, NPC Rex). Zweihander is sold in V plus G5. Sources: [l2hub.info](https://l2hub.info/il/items/long_sword/shops), [l2hub.info](https://l2hub.info/il/items/zweihander/shops), [github:DEVjEXTREME/L2jaCis-409](https://github.com/DEVjEXTREME/L2jaCis-409/blob/main/aCis_datapack/data/xml/buyLists.xml).
- **D-grade: where sold**: Low tier (409,000 to 716,000 weapons, plus Mithril Breastplate, Mithril Gaiters, Tunic of Knowledge and Stockings of Knowledge) is sold in every T town. Mage weapons and robes are also sold at Ivory Tower. Mid tier (967,000 to 1,400,000 weapons, plus Brigandine, Reinforced Leather, Manticore Skin and Mithril Tunic pieces) is sold in G5. l2hub confirms this for the weapons, Winged Spear and Bich'Hwa included. Exception: l2hub lists Morning Star (1,400,000) in all T towns, while L2J and aCis give it to the GM shop only. CONFLICT: l2hub also lists Woodley (Town of Aden) selling Brigandine Tunic/Gaiters, Reinforced Leather Shirt/Gaiters, Manticore Skin Shirt/Gaiters, Helmet and Hoplon, while L2J and aCis give Woodley only the low tier. Not sold anywhere: the top D tier (1,800,000), Knight's Sword, Spinebone Sword, Scalpel, Mace of Judgment, Mace of Miracle, Skull Breaker, Glaive, Scallop Jamadhr, the D-grade gloves and boots, Brigandine Helmet and Brigandine Shield. Sources: [l2hub.info](https://l2hub.info/il/items/crimson_sword/shops), [l2hub.info](https://l2hub.info/il/items/morning_star/shops), [l2hub.info](https://l2hub.info/il/items/brigandine/shops), [github:DEVjEXTREME/L2jaCis-409](https://github.com/DEVjEXTREME/L2jaCis-409/blob/main/aCis_datapack/data/xml/buyLists.xml).
- **C, B, A, S grade: where sold**: No NPC shop sells any C, B, A or S grade weapon or armour. l2hub shows no shop tab on any of them, and L2J/aCis sell them only from the GM shop. They come from crafting, drops and spoil. Sources: [l2hub.info](https://l2hub.info/il/items/stormbringer), [github:Hl4p3x/L2JServer_C6_Interlude](https://github.com/Hl4p3x/L2JServer_C6_Interlude/blob/master/dist/db_installer/sql/install/merchant_buylists.sql).

## No-grade swords

- **Short Sword**: No-grade, 1H sword. P.Atk 8, M.Atk 6, price 768. Shops: V. Sources: [l2hub.info](https://l2hub.info/il/items/short_sword), [l2db.ru](https://l2db.ru/items/weapons/sword/interlude).
- **Broadsword**: No-grade, 1H. P.Atk 11, M.Atk 9, price 12,500. Shops: V. One word, although the recipe is spelled 'Recipe: Broad Sword'. Sources: [l2hub.info](https://l2hub.info/il/items/broad_sword), [l2db.ru](https://l2db.ru/items/weapons/sword/interlude).
- **Gladius**: No-grade, 1H. P.Atk 17, M.Atk 12, price 54,100. Shops: V. Orcish Sword and Handmade Sword have the same stats and price and are also sold in V. Sources: [l2hub.info](https://l2hub.info/il/items/gladius), [l2db.ru](https://l2db.ru/items/weapons/sword/interlude).
- **Long Sword**: No-grade, 1H. P.Atk 24, M.Atk 17, price 136,000. Shops: every V and T town (19 traders). Sources: [l2hub.info](https://l2hub.info/il/items/long_sword), [l2db.ru](https://l2db.ru/items/weapons/sword/interlude).
- **Falchion**: No-grade, 1H. P.Atk 31, M.Atk 21, price 244,000. Shops: T. Sources: [l2hub.info](https://l2hub.info/il/items/falchion), [l2db.ru](https://l2db.ru/items/weapons/sword/interlude).
- **Brandish**: No-grade, 2H sword. P.Atk 21, M.Atk 12, price 54,100. Shops: V. Sources: [l2hub.info](https://l2hub.info/il/items/brandish), [l2db.ru](https://l2db.ru/items/weapons/sword/interlude).
- **Zweihander**: No-grade, 2H sword. P.Atk 38, M.Atk 21, price 244,000. Shops: V plus G5. Sources: [l2hub.info](https://l2hub.info/il/items/zweihander), [l2db.ru](https://l2db.ru/items/weapons/sword/interlude).

## No-grade blunt weapons

- **Club**: No-grade, 1H blunt. P.Atk 8, M.Atk 6, price 768. Shops: V. Sources: [l2hub.info](https://l2hub.info/il/items/club), [l2db.ru](https://l2db.ru/items/weapons/blunt/interlude).
- **Mace**: No-grade, 1H. P.Atk 11, M.Atk 9, price 12,500. Shops: V. Also in V: Heavy Chisel (P.Atk 10, M.Atk 8, 8,070) and Sickle (P.Atk 12, M.Atk 9, 18,500). Sources: [l2hub.info](https://l2hub.info/il/items/mace), [l2db.ru](https://l2db.ru/items/weapons/blunt/interlude).
- **Dwarven Mace**: No-grade, 1H. P.Atk 17, M.Atk 12, price 54,100. Shops: V. Sources: [l2hub.info](https://l2hub.info/il/items/dwarven_mace), [l2db.ru](https://l2db.ru/items/weapons/blunt/interlude).
- **Iron Hammer**: No-grade, 1H. P.Atk 31, M.Atk 21, price 244,000. Shops: T. Buzdygan has the same stats and is also sold in T. Sources: [l2hub.info](https://l2hub.info/il/items/iron_hammer), [l2db.ru](https://l2db.ru/items/weapons/blunt/interlude).
- **Willow Staff**: No-grade, 2H staff. P.Atk 11, M.Atk 12, price 12,500. Shops: V. Cedar Staff is P.Atk 16, M.Atk 16, price 54,100, also sold in V. Apprentice's Rod (1H, P.Atk 6, M.Atk 8, price 768) is sold in V. Sources: [l2hub.info](https://l2hub.info/il/items/willow_staff), [l2db.ru](https://l2db.ru/items/weapons/blunt/interlude).
- **Mage Staff**: No-grade, 2H staff. P.Atk 30, M.Atk 28, price 244,000. Shops: T plus Ivory Tower (Rex). Journeyman's Staff is P.Atk 23, M.Atk 22, price 136,000, sold in every V and T town plus Ivory Tower. Sources: [l2hub.info](https://l2hub.info/il/items/mage_staff/shops), [l2db.ru](https://l2db.ru/items/weapons/blunt/interlude).

## No-grade daggers

- **Knife**: No-grade dagger. P.Atk 10, M.Atk 9, price 12,500. Shops: V. Doom Dagger has the same stats and is also sold in V. Bone Dagger is P.Atk 7, M.Atk 6, price 768, sold in V. Sources: [l2hub.info](https://l2hub.info/il/items/knife), [l2db.ru](https://l2db.ru/items/weapons/dagger/interlude).
- **Dirk**: No-grade dagger. P.Atk 15, M.Atk 12, price 54,100. Shops: V. Sources: [l2hub.info](https://l2hub.info/il/items/dirk), [l2db.ru](https://l2db.ru/items/weapons/dagger/interlude).
- **Throwing Knife**: No-grade dagger. P.Atk 21, M.Atk 17, price 136,000. Shops: every V and T town. Shining Knife has the same stats but is not sold. Sources: [l2hub.info](https://l2hub.info/il/items/throwing_knife), [l2db.ru](https://l2db.ru/items/weapons/dagger/interlude).
- **Sword Breaker**: No-grade dagger. P.Atk 27, M.Atk 21, price 244,000. Shops: T. Sources: [l2hub.info](https://l2hub.info/il/items/sword_breaker), [l2db.ru](https://l2db.ru/items/weapons/dagger/interlude).

## No-grade bows

- **Short Bow**: No-grade bow. P.Atk 16, M.Atk 6, price 768. Shops: V. Sources: [l2hub.info](https://l2hub.info/il/items/short_bow), [l2db.ru](https://l2db.ru/items/weapons/bow/interlude).
- **Bow**: No-grade bow. P.Atk 23, M.Atk 9, price 12,500. Shops: V. Sources: [l2hub.info](https://l2hub.info/il/items/bow), [l2db.ru](https://l2db.ru/items/weapons/bow/interlude).
- **Hunting Bow**: No-grade bow. P.Atk 34, M.Atk 12, price 54,100. Shops: V. Sources: [l2hub.info](https://l2hub.info/il/items/hunting_bow), [l2db.ru](https://l2db.ru/items/weapons/bow/interlude).
- **Forest Bow**: No-grade bow. P.Atk 49, M.Atk 17, price 136,000. Shops: every V and T town. Sources: [l2hub.info](https://l2hub.info/il/items/forest_bow), [l2db.ru](https://l2db.ru/items/weapons/bow/interlude).
- **Composition Bow**: No-grade bow. P.Atk 64, M.Atk 21, price 244,000. Shops: T. Sources: [l2hub.info](https://l2hub.info/il/items/composition_bow), [l2db.ru](https://l2db.ru/items/weapons/bow/interlude).

## No-grade polearms

- **Short Spear**: ADDED. No-grade polearm (2H). P.Atk 24, M.Atk 17, price 136,000. Shops: every V and T town. Long Spear is P.Atk 31, M.Atk 21, price 244,000, sold in T. Sources: [l2hub.info](https://l2hub.info/il/items/short_spear), [github:Hl4p3x/L2JServer_C6_Interlude](https://github.com/Hl4p3x/L2JServer_C6_Interlude/blob/master/dist/game/data/stats/items/0000-0099.xml).

## No-grade fist weapons

- **Cestus**: ADDED. No-grade fist weapon (dualfist). P.Atk 29, M.Atk 17, price 136,000. Shops: T plus Orc Village. Sources: [l2hub.info](https://l2hub.info/il/items/cestus), [github:Hl4p3x/L2JServer_C6_Interlude](https://github.com/Hl4p3x/L2JServer_C6_Interlude/tree/master/dist/game/data/stats/items).

## D-grade swords

- **Saber**: D-grade, 1H. P.Atk 40, M.Atk 26, price 409,000. Shops: T. Sources: [l2hub.info](https://l2hub.info/il/items/saber), [l2db.ru](https://l2db.ru/items/weapons/sword/interlude).
- **Bastard Sword**: D-grade, 1H (item id 69). P.Atk 51, M.Atk 32, price 644,000. Shops: T. Artisan's Sword has the same stats and is sold in G5 only. Knight's Sword and Spinebone Sword have the same stats and are not sold. A second, unrelated 'Bastard Sword' (id 1297, no grade, P.Atk 22) exists in the data and is not player gear. Sources: [l2hub.info](https://l2hub.info/il/items/bastard_sword), [l2db.ru](https://l2db.ru/items/weapons/sword/interlude).
- **Crimson Sword**: D-grade, 1H. P.Atk 64, M.Atk 39, price 967,000. Shops: G5. Elven Sword has the same stats and shops. Sources: [l2hub.info](https://l2hub.info/il/items/crimson_sword/shops), [l2db.ru](https://l2db.ru/items/weapons/sword/interlude).
- **Sword of Revolution**: D-grade, 1H. P.Atk 79, M.Atk 47, price 1,400,000. Shops: G5. Sources: [l2hub.info](https://l2hub.info/il/items/sword_of_revolution), [l2db.ru](https://l2db.ru/items/weapons/sword/interlude).
- **Elven Long Sword**: D-grade, 1H. P.Atk 92, M.Atk 54, price 1,800,000. Top D-grade 1H sword. Not sold. Sources: [l2hub.info](https://l2hub.info/il/items/elven_long_sword), [l2db.ru](https://l2db.ru/items/weapons/sword/interlude).
- **Two-Handed Sword**: D-grade, 2H. P.Atk 78, M.Atk 39, price 967,000. Shops: G5. Sources: [l2hub.info](https://l2hub.info/il/items/two-handed_sword), [l2db.ru](https://l2db.ru/items/weapons/sword/interlude).
- **Titan Sword**: D-grade, 2H. P.Atk 96, M.Atk 47. Shops: G5. Price CONFLICTS: 1,400,000 per L2J and l2db.ru, 1,396,200 per aCis, 1,074,000 per l2hub. Sources: [l2hub.info](https://l2hub.info/il/items/titan_sword), [l2db.ru](https://l2db.ru/items/weapons/sword/interlude).
- **Claymore**: D-grade, 2H. P.Atk 112, M.Atk 54, price 1,800,000. Not sold. Sources: [l2hub.info](https://l2hub.info/il/items/claymore), [l2db.ru](https://l2db.ru/items/weapons/sword/interlude).
- **Sword of Mystic**: D-grade, 1H mage sword. P.Atk 43, M.Atk 45, price 716,000. Shops: T plus Ivory Tower. Sword of Magic and Sword of Occult have the same stats and shops. Sources: [l2hub.info](https://l2hub.info/il/items/sword_of_mystic), [l2db.ru](https://l2db.ru/items/weapons/sword/interlude).

## D-grade blunt weapons

- **Hand Axe**: D-grade, 1H. P.Atk 40, M.Atk 26, price 409,000. Shops: T. Heavy Mace and Work Hammer have the same stats and are sold in T. Scalpel has the same stats and is not sold. Sources: [l2hub.info](https://l2hub.info/il/items/hand_axe), [l2db.ru](https://l2db.ru/items/weapons/blunt/interlude).
- **Tomahawk**: D-grade, 1H. P.Atk 51, M.Atk 32, price 644,000. Shops: G5. Sources: [l2hub.info](https://l2hub.info/il/items/tomahawk), [l2db.ru](https://l2db.ru/items/weapons/blunt/interlude).
- **Spiked Club**: D-grade, 1H. P.Atk 64, M.Atk 39, price 967,000. Shops: G5. Sources: [l2hub.info](https://l2hub.info/il/items/spiked_club), [l2db.ru](https://l2db.ru/items/weapons/blunt/interlude).
- **Tarbar**: D-grade, 1H. P.Atk 79, M.Atk 47, price 1,400,000. Shops: G5. Heavy Bone Club has the same stats and shops. Skull Breaker has the same stats and is not sold. Morning Star has the same stats, but sources disagree on its shops: l2hub lists 14 T-town traders, while L2J and aCis give it only to the GM shop. Sources: [l2hub.info](https://l2hub.info/il/items/morning_star/shops), [l2db.ru](https://l2db.ru/items/weapons/blunt/interlude).
- **Bonebreaker**: D-grade, 1H. P.Atk 92, M.Atk 54, price 1,800,000. Not sold. Staff of Life is the 1H mage blunt of that tier (P.Atk 74, M.Atk 72, 1,800,000, not sold). Sources: [l2hub.info](https://l2hub.info/il/items/bonebreaker), [l2db.ru](https://l2db.ru/items/weapons/blunt/interlude).
- **Mace of Prayer**: D-grade, 1H mage blunt. P.Atk 41, M.Atk 43, price 644,000. Shops: T plus Ivory Tower. Doom Hammer has the same stats and shops. Mace of Judgment and Mace of Miracle have the same stats and are not sold. Sources: [l2hub.info](https://l2hub.info/il/items/mace_of_prayer), [l2db.ru](https://l2db.ru/items/weapons/blunt/interlude).
- **Goat Head Staff**: D-grade, 2H staff. P.Atk 77, M.Atk 63, price 1,400,000. Shops: G5 plus Ivory Tower. Sources: [l2hub.info](https://l2hub.info/il/items/goat_head_staff), [l2db.ru](https://l2db.ru/items/weapons/blunt/interlude).
- **Ghost Staff**: D-grade, 2H staff. P.Atk 90, M.Atk 72, price 1,800,000. Not sold. Atuba Hammer and Atuba Mace are both 2H blunts with the same stats, also not sold. Sources: [l2hub.info](https://l2hub.info/il/items/ghost_staff), [l2db.ru](https://l2db.ru/items/weapons/blunt/interlude).

## D-grade daggers

- **Crafted Dagger**: D-grade dagger. P.Atk 35, M.Atk 26, price 409,000. Shops: T. Assassin Knife has the same stats and shops. Sources: [l2hub.info](https://l2hub.info/il/items/crafted_dagger), [l2db.ru](https://l2db.ru/items/weapons/dagger/interlude).
- **Poniard Dagger**: D-grade dagger. P.Atk 45, M.Atk 32, price 644,000. Shops: T. Sources: [l2hub.info](https://l2hub.info/il/items/poniard_dagger), [l2db.ru](https://l2db.ru/items/weapons/dagger/interlude).
- **Kukuri**: D-grade dagger. P.Atk 56, M.Atk 39, price 967,000. Shops: G5. Sources: [l2hub.info](https://l2hub.info/il/items/kukuri), [l2db.ru](https://l2db.ru/items/weapons/dagger/interlude).
- **Maingauche**: D-grade dagger. P.Atk 69, M.Atk 47, price 1,400,000. Shops: G5. Cursed Maingauche is P.Atk 62, M.Atk 42, with the same price and shops. Sources: [l2hub.info](https://l2hub.info/il/items/maingauche), [l2db.ru](https://l2db.ru/items/weapons/dagger/interlude).
- **Mithril Dagger**: D-grade dagger. P.Atk 80, M.Atk 54, price 1,800,000. Not sold. Sources: [l2hub.info](https://l2hub.info/il/items/mithril_dagger), [l2db.ru](https://l2db.ru/items/weapons/dagger/interlude).
- **Dagger of Mana**: D-grade mage dagger. P.Atk 45, M.Atk 52, price 967,000. Shops: T plus Ivory Tower. Mystic Knife and Conjurer's Knife have the same stats and shops. Shilen Knife has the same stats and is sold in G5 plus Ivory Tower. Sources: [l2hub.info](https://l2hub.info/il/items/dagger_of_mana), [l2db.ru](https://l2db.ru/items/weapons/dagger/interlude).

## D-grade bows

- **Strengthened Bow**: D-grade bow. P.Atk 82, M.Atk 26, price 409,000. Shops: T. Sources: [l2hub.info](https://l2hub.info/il/items/strengthened_bow), [l2db.ru](https://l2db.ru/items/weapons/bow/interlude).
- **Long Bow**: D-grade bow. P.Atk 114, M.Atk 35, price 644,000. Shops: T. Dark Elven Bow is P.Atk 105, M.Atk 32, same price, sold in T. Elven Bow has the same stats as Dark Elven Bow and is sold in G5. Sources: [l2hub.info](https://l2hub.info/il/items/long_bow), [l2db.ru](https://l2db.ru/items/weapons/bow/interlude).
- **Gastraphetes**: D-grade bow. P.Atk 132, M.Atk 39, price 967,000. Shops: G5. Sources: [l2hub.info](https://l2hub.info/il/items/gastraphetes), [l2db.ru](https://l2db.ru/items/weapons/bow/interlude).
- **Strengthened Long Bow**: D-grade bow. P.Atk 179, M.Atk 51, price 1,400,000. Shops: G5. Sources: [l2hub.info](https://l2hub.info/il/items/strengthened_long_bow), [l2db.ru](https://l2db.ru/items/weapons/bow/interlude).
- **Light Crossbow**: D-grade bow-type weapon. P.Atk 191, M.Atk 54, price 1,800,000. Not sold. Its internal name is cyclone_bow. Sources: [l2hub.info](https://l2hub.info/il/items/cyclone_bow), [l2db.ru](https://l2db.ru/items/weapons/bow/interlude).

## D-grade polearms

- **Trident**: ADDED. D-grade polearm. P.Atk 40, M.Atk 26, price 409,000. Shops: T. Pike and Dwarven Trident are P.Atk 51, M.Atk 32, price 644,000, sold in T. Winged Spear is P.Atk 79, M.Atk 47, price 1,400,000, sold in G5. Glaive is P.Atk 92, M.Atk 54, price 1,800,000, not sold. Sources: [l2hub.info](https://l2hub.info/il/items/trident), [github:Hl4p3x/L2JServer_C6_Interlude](https://github.com/Hl4p3x/L2JServer_C6_Interlude/tree/master/dist/game/data/stats/items).

## D-grade fist weapons

- **Bich'Hwa**: ADDED. D-grade fist weapon. P.Atk 96, M.Atk 47, price 1,400,000. Shops: G5. Scallop Jamadhr is P.Atk 112, M.Atk 54, price 1,800,000, not sold. Sources: [l2hub.info](https://l2hub.info/il/items/bich'hwa), [github:Hl4p3x/L2JServer_C6_Interlude](https://github.com/Hl4p3x/L2JServer_C6_Interlude/tree/master/dist/game/data/stats/items).

## C-grade swords

- **Stormbringer**: C-grade, 1H. P.Atk 107, M.Atk 61, price 2,290,000. Not sold. Sources: [l2hub.info](https://l2hub.info/il/items/stormbringer), [l2db.ru](https://l2db.ru/items/weapons/sword/interlude).
- **Shamshir**: C-grade, 1H. P.Atk 122, M.Atk 68, price 2,870,000. Katana, Spirit Sword and Raid Sword have the same stats. Sources: [l2hub.info](https://l2hub.info/il/items/shamshir), [l2db.ru](https://l2db.ru/items/weapons/sword/interlude).
- **Caliburs**: C-grade, 1H. P.Atk 139, M.Atk 76, price 4,300,000. Sword of Delusion, Tsurugi, Sword of Limit and Sword of Nightmare have the same stats. Sources: [l2hub.info](https://l2hub.info/il/items/caliburs), [l2db.ru](https://l2db.ru/items/weapons/sword/interlude).
- **Samurai Longsword**: C-grade, 1H. P.Atk 156, M.Atk 83, price 6,130,000. Top C-grade 1H sword. The single item is spelled 'Samurai Longsword', but the client's dual-sword names spell it 'Samurai Long Sword' (e.g. 'Samurai Long Sword*Samurai Long Sword'). Sources: [l2hub.info](https://l2hub.info/il/items/samurai_longsword), [l2db.ru](https://l2db.ru/items/weapons/sword/interlude).
- **Flamberge**: C-grade, 2H. P.Atk 130, M.Atk 61, price 2,290,000. Sources: [l2hub.info](https://l2hub.info/il/items/flamberge), [l2db.ru](https://l2db.ru/items/weapons/sword/interlude).
- **Pa'agrian Sword**: C-grade, 2H. P.Atk 169, M.Atk 76. Price CONFLICTS: 4,300,000 per L2J and l2db.ru, 3,304,300 per l2hub. Sources: [l2hub.info](https://l2hub.info/il/items/sword_of_paagrio), [l2db.ru](https://l2db.ru/items/weapons/sword/interlude).
- **Berserker Blade**: C-grade, 2H. P.Atk 190, M.Atk 83, price 6,130,000. Sources: [l2hub.info](https://l2hub.info/il/items/berserker_blade), [l2db.ru](https://l2db.ru/items/weapons/sword/interlude).
- **Homunkulus's Sword**: C-grade, 1H mage sword. P.Atk 111, M.Atk 101, price 4,300,000. 'Homunkulus' is the game's spelling. Sword of Whispering Death has the same stats. Ecliptic Sword is P.Atk 125, M.Atk 111; its price is 6,130,000 per L2J and l2db.ru and 4,713,500 per l2hub. Sources: [l2hub.info](https://l2hub.info/il/items/homunkulus's_sword), [l2db.ru](https://l2db.ru/items/weapons/sword/interlude).

## C-grade blunt weapons

- **Big Hammer**: C-grade, 1H. P.Atk 107, M.Atk 61, price 2,290,000. Battle Axe, Silver Axe and Skull Graver have the same stats. Sources: [l2hub.info](https://l2hub.info/il/items/big_hammer), [l2db.ru](https://l2db.ru/items/weapons/blunt/interlude).
- **Dwarven War Hammer**: C-grade, 1H. P.Atk 122, M.Atk 68, price 2,870,000. Sources: [l2hub.info](https://l2hub.info/il/items/dwarven_war_hammer), [l2db.ru](https://l2db.ru/items/weapons/blunt/interlude).
- **War Axe**: C-grade, 1H. P.Atk 139, M.Atk 76, price 4,300,000. Sources: [l2hub.info](https://l2hub.info/il/items/war_axe), [l2db.ru](https://l2db.ru/items/weapons/blunt/interlude).
- **Yaksa Mace**: C-grade, 1H. P.Atk 156, M.Atk 83, price 6,130,000. Top C-grade 1H blunt. Sources: [l2hub.info](https://l2hub.info/il/items/yaksa_mace), [l2db.ru](https://l2db.ru/items/weapons/blunt/interlude).
- **Dwarven Hammer**: C-grade, 2H. P.Atk 190, M.Atk 83; price 6,130,000 per L2J and 4,713,500 per l2hub. Karik Horn is 2H, P.Atk 169, M.Atk 76; price 4,300,000 per L2J and 3,304,300 per l2hub. Sources: [l2hub.info](https://l2hub.info/il/items/dwarven_hammer), [l2db.ru](https://l2db.ru/items/weapons/blunt/interlude).
- **Sage's Staff**: C-grade, 2H staff. P.Atk 135, M.Atk 101, price 4,300,000. Paradia Staff, Inferno Staff and Pa'agrian Hammer have the same stats. Pa'agrian Axe is P.Atk 141, M.Atk 104, price 4,780,000. Sources: [l2hub.info](https://l2hub.info/il/items/sage's_staff), [l2db.ru](https://l2db.ru/items/weapons/blunt/interlude).
- **Demon's Staff**: C-grade, 2H staff. P.Atk 152, M.Atk 111, price 6,130,000. Deadman's Staff and Ghoul's Staff have the same stats. Sources: [l2hub.info](https://l2hub.info/il/items/demon's_staff), [l2db.ru](https://l2db.ru/items/weapons/blunt/interlude).

## C-grade daggers

- **Cursed Dagger**: C-grade dagger. P.Atk 94, M.Atk 61, price 2,290,000. Dark Elven Dagger and Wolverine Needle have the same stats. Sources: [l2hub.info](https://l2hub.info/il/items/cursed_dagger), [l2db.ru](https://l2db.ru/items/weapons/dagger/interlude).
- **Stiletto**: C-grade dagger. P.Atk 107, M.Atk 68, price 2,870,000. Sources: [l2hub.info](https://l2hub.info/il/items/stiletto), [l2db.ru](https://l2db.ru/items/weapons/dagger/interlude).
- **Grace Dagger**: C-grade dagger. P.Atk 122, M.Atk 76, price 4,300,000. Dark Screamer has the same stats. Sources: [l2hub.info](https://l2hub.info/il/items/grace_dagger), [l2db.ru](https://l2db.ru/items/weapons/dagger/interlude).
- **Crystal Dagger**: C-grade dagger. P.Atk 136, M.Atk 83, price 6,130,000. Top C-grade dagger. Soulfire Dirk (mage dagger) is P.Atk 86, M.Atk 91, price 2,870,000. Sources: [l2hub.info](https://l2hub.info/il/items/crystal_dagger), [l2db.ru](https://l2db.ru/items/weapons/dagger/interlude).

## C-grade bows

- **Crystallized Ice Bow**: C-grade bow. P.Atk 220, M.Atk 61, price 2,290,000. Sources: [l2hub.info](https://l2hub.info/il/items/crystallized_ice_bow), [l2db.ru](https://l2db.ru/items/weapons/bow/interlude).
- **Noble Elven Bow**: C-grade bow. P.Atk 252, M.Atk 68, price 2,870,000. Sources: [l2hub.info](https://l2hub.info/il/items/noble_elven_bow), [l2db.ru](https://l2db.ru/items/weapons/bow/interlude).
- **Elemental Bow**: C-grade bow. P.Atk 277, M.Atk 75, price 2,870,000. Sources: [l2hub.info](https://l2hub.info/il/items/elemental_bow), [l2db.ru](https://l2db.ru/items/weapons/bow/interlude).
- **Akat Long Bow**: C-grade bow. P.Atk 316, M.Atk 84, price 4,300,000. Sources: [l2hub.info](https://l2hub.info/il/items/akat_long_bow), [l2db.ru](https://l2db.ru/items/weapons/bow/interlude).
- **Eminence Bow**: C-grade bow. P.Atk 323, M.Atk 83, price 6,130,000. Sources: [l2hub.info](https://l2hub.info/il/items/eminence_bow), [l2db.ru](https://l2db.ru/items/weapons/bow/interlude).

## C-grade polearms

- **Scythe**: ADDED. C-grade polearms. Scythe, Orcish Glaive and Body Slasher are P.Atk 107, M.Atk 61, price 2,290,000. Poleaxe is P.Atk 139, M.Atk 76, price 4,300,000. Scorpion and Widow Maker are P.Atk 144, M.Atk 78, price 4,780,000. Orcish Poleaxe is P.Atk 156, M.Atk 83, price 6,130,000. Sources: [l2hub.info](https://l2hub.info/il/items/scythe), [github:Hl4p3x/L2JServer_C6_Interlude](https://github.com/Hl4p3x/L2JServer_C6_Interlude/tree/master/dist/game/data/stats/items).

## C-grade fist weapons

- **Chakram**: ADDED. C-grade fist weapons. Chakram is P.Atk 130, M.Atk 61, price 2,290,000. Knuckle Duster is P.Atk 148, M.Atk 68, price 2,870,000. Great Pata is P.Atk 190, M.Atk 83, price 6,130,000. Sources: [l2hub.info](https://l2hub.info/il/items/chakram), [github:Hl4p3x/L2JServer_C6_Interlude](https://github.com/Hl4p3x/L2JServer_C6_Interlude/tree/master/dist/game/data/stats/items).

## B-grade swords

- **Keshanberk**: B-grade, 1H. P.Atk 175, M.Atk 91, price 8,680,000. No B-grade weapon is sold in shops. (The researcher's same-stat list of Blade of Serenity, Mist Sword, Sword of Desert, Dusk Sword, Eminence Sword and Hazard Sword has been removed; see caveats.) Sources: [l2hub.info](https://l2hub.info/il/items/keshanberk), [l2db.ru](https://l2db.ru/items/weapons/sword/interlude).
- **Sword of Damascus**: B-grade, 1H. P.Atk 194, M.Atk 99, price 13,100,000. Sources: [l2hub.info](https://l2hub.info/il/items/sword_of_damascus), [l2db.ru](https://l2db.ru/items/weapons/sword/interlude).
- **Great Sword**: B-grade, 2H (item id 78). P.Atk 213, M.Atk 91, price 8,680,000. A non-grade item id 1299 is also named 'Great Sword' and is not player gear. Sources: [l2hub.info](https://l2hub.info/il/items/great_sword), [l2db.ru](https://l2db.ru/items/weapons/sword/interlude).
- **Guardian Sword**: B-grade, 2H. P.Atk 236, M.Atk 99. Price 13,100,000 per L2J and l2db.ru, 10,091,400 per l2hub. Sources: [l2hub.info](https://l2hub.info/il/items/guardian_sword), [l2db.ru](https://l2db.ru/items/weapons/sword/interlude).
- **Sword of Valhalla**: B-grade, 1H mage sword. P.Atk 140, M.Atk 122, price 8,680,000. Ghoulbane has the same stats. Wizard's Tear is P.Atk 155, M.Atk 132; its price is 13,100,000 per L2J and l2db.ru and 10,091,400 per l2hub. Sources: [l2hub.info](https://l2hub.info/il/items/sword_of_valhalla), [l2db.ru](https://l2db.ru/items/weapons/sword/interlude).

## B-grade blunt weapons

- **Heavy War Axe**: B-grade, 1H. P.Atk 175, M.Atk 91, price 8,680,000. Sources: [l2hub.info](https://l2hub.info/il/items/heavy_war_axe), [l2db.ru](https://l2db.ru/items/weapons/blunt/interlude).
- **Art of Battle Axe**: B-grade, 1H. P.Atk 194, M.Atk 99, price 13,100,000. Deadman's Glory has the same stats. Sources: [l2hub.info](https://l2hub.info/il/items/art_of_battle_axe), [l2db.ru](https://l2db.ru/items/weapons/blunt/interlude).
- **Star Buster**: B-grade, 2H. P.Atk 236, M.Atk 99; price 13,100,000 per L2J and 10,091,400 per l2hub. Ice Storm Hammer is 2H, P.Atk 213, M.Atk 91; price 8,680,000 per L2J and 6,680,500 per l2hub. Sources: [l2hub.info](https://l2hub.info/il/items/star_buster), [l2db.ru](https://l2db.ru/items/weapons/blunt/interlude).
- **Sprite's Staff**: B-grade, 2H staff. P.Atk 170, M.Atk 122, price 8,680,000. Staff of Phantom and Staff of Seal have the same stats. Sources: [l2hub.info](https://l2hub.info/il/items/sprite's_staff), [l2db.ru](https://l2db.ru/items/weapons/blunt/interlude).
- **Staff of Evil Spirits**: B-grade, 2H staff. P.Atk 189, M.Atk 132, price 13,100,000. Divine Staff and Staff of Nobility have the same stats. Sources: [l2hub.info](https://l2hub.info/il/items/staff_of_evil_spirits), [l2db.ru](https://l2db.ru/items/weapons/blunt/interlude).
- **Kaim Vanul's Bones**: B-grade, 1H mage blunt. P.Atk 155, M.Atk 132; price 13,100,000 per L2J and 10,091,400 per l2hub. Spell Breaker is P.Atk 140, M.Atk 122; price 8,680,000 per L2J and 6,680,500 per l2hub. Sources: [l2hub.info](https://l2hub.info/il/items/bone_of_kaim_vanul), [l2db.ru](https://l2db.ru/items/weapons/blunt/interlude).

## B-grade daggers

- **Kris**: B-grade dagger. P.Atk 153, M.Atk 91, price 8,680,000. Sources: [l2hub.info](https://l2hub.info/il/items/kris), [l2db.ru](https://l2db.ru/items/weapons/dagger/interlude).
- **Demon Dagger**: B-grade dagger. P.Atk 170, M.Atk 99, price 13,100,000. Sources: [l2hub.info](https://l2hub.info/il/items/demon_dagger), [l2db.ru](https://l2db.ru/items/weapons/dagger/interlude).
- **Hell Knife**: B-grade mage dagger. P.Atk 122, M.Atk 122, price 8,680,000. Sources: [l2hub.info](https://l2hub.info/il/items/hell_knife), [l2db.ru](https://l2db.ru/items/weapons/dagger/interlude).

## B-grade bows

- **Dark Elven Long Bow**: B-grade bow. P.Atk 397, M.Atk 100, price 8,680,000. Sources: [l2hub.info](https://l2hub.info/il/items/dark_elven_long_bow), [l2db.ru](https://l2db.ru/items/weapons/bow/interlude).
- **Bow of Peril**: B-grade bow. P.Atk 400, M.Atk 99, price 13,100,000. Sources: [l2hub.info](https://l2hub.info/il/items/bow_of_peril), [l2db.ru](https://l2db.ru/items/weapons/bow/interlude).

## B-grade polearms

- **Great Axe**: ADDED. B-grade polearm. P.Atk 175, M.Atk 91, price 8,680,000. Lance is P.Atk 194, M.Atk 99, price 13,100,000. Sources: [l2hub.info](https://l2hub.info/il/items/great_axe), [github:Hl4p3x/L2JServer_C6_Interlude](https://github.com/Hl4p3x/L2JServer_C6_Interlude/tree/master/dist/game/data/stats/items).

## B-grade fist weapons

- **Arthro Nail**: ADDED. B-grade fist weapon. P.Atk 213, M.Atk 91, price 8,680,000. Bellion Cestus is P.Atk 236, M.Atk 99, price 13,100,000. Sources: [l2hub.info](https://l2hub.info/il/items/arthro_nail), [github:Hl4p3x/L2JServer_C6_Interlude](https://github.com/Hl4p3x/L2JServer_C6_Interlude/tree/master/dist/game/data/stats/items).

## A-grade swords

- **Tallum Blade**: A-grade, 1H. P.Atk 213, M.Atk 107, price 18,300,000. Not sold. Sources: [l2hub.info](https://l2hub.info/il/items/tallum_blade), [l2db.ru](https://l2db.ru/items/weapons/sword/interlude).
- **Dark Legion's Edge**: A-grade, 1H. P.Atk 232, M.Atk 114, price 27,000,000. Sources: [l2hub.info](https://l2hub.info/il/items/dark_legion's_edge), [l2db.ru](https://l2db.ru/items/weapons/sword/interlude).
- **Infernal Master**: A-grade, 2H. P.Atk 259, M.Atk 107. Price 18,300,000 per L2J and l2db.ru, 14,098,000 per l2hub. Sources: [l2hub.info](https://l2hub.info/il/items/infernal_master), [l2db.ru](https://l2db.ru/items/weapons/sword/interlude).
- **Dragon Slayer**: A-grade, 2H. P.Atk 282, M.Atk 114, price 27,000,000. Sources: [l2hub.info](https://l2hub.info/il/items/dragon_slayer), [l2db.ru](https://l2db.ru/items/weapons/sword/interlude).
- **Sword of Miracles**: A-grade, 1H mage sword. P.Atk 186, M.Atk 152, price 27,000,000. Elemental Sword, Phantom Sword, Sword of Life and Tear of Darkness are P.Atk 170, M.Atk 143, price 18,300,000. Sources: [l2hub.info](https://l2hub.info/il/items/sword_of_miracles), [l2db.ru](https://l2db.ru/items/weapons/sword/interlude).

## A-grade blunt weapons

- **Meteor Shower**: A-grade, 1H. P.Atk 213, M.Atk 107, price 18,300,000. Sources: [l2hub.info](https://l2hub.info/il/items/meteor_shower), [l2db.ru](https://l2db.ru/items/weapons/blunt/interlude).
- **Elysian**: A-grade, 1H. P.Atk 232, M.Atk 114, price 27,000,000. Sources: [l2hub.info](https://l2hub.info/il/items/elysian), [l2db.ru](https://l2db.ru/items/weapons/blunt/interlude).
- **Doom Crusher**: A-grade, 2H. P.Atk 282, M.Atk 114; price 27,000,000 per L2J and 20,741,000 per l2hub. Destroyer Hammer is 2H, P.Atk 259, M.Atk 107; price 18,300,000 per L2J and 14,098,000 per l2hub. Sources: [l2hub.info](https://l2hub.info/il/items/doom_crusher), [l2db.ru](https://l2db.ru/items/weapons/blunt/interlude).
- **Branch of The Mother Tree**: A-grade, 2H staff. P.Atk 226, M.Atk 152, price 27,000,000. The capital 'The' is the game's own: l2hub and L2J both have it, while one other datapack writes 'Branch of the Mother Tree' with M.Atk 167. Dasparion's Staff is 2H, P.Atk 207, M.Atk 143, price 18,300,000. Sources: [l2hub.info](https://l2hub.info/il/items/worldtree's_branch), [github:Hl4p3x/L2JServer_C6_Interlude](https://github.com/Hl4p3x/L2JServer_C6_Interlude/tree/master/dist/game/data/stats/items).
- **Flaming Dragon Skull**: A-grade, 1H mage blunt. P.Atk 186, M.Atk 152; price 27,000,000 per L2J and 20,741,000 per l2hub. Spiritual Eye is P.Atk 170, M.Atk 143; price 18,300,000 per L2J and 14,098,000 per l2hub. Sources: [l2hub.info](https://l2hub.info/il/items/flaming_dragon_skull), [l2db.ru](https://l2db.ru/items/weapons/blunt/interlude).

## A-grade daggers

- **Bloody Orchid**: A-grade dagger. P.Atk 186, M.Atk 107, price 18,300,000. Sources: [l2hub.info](https://l2hub.info/il/items/bloody_orchid), [l2db.ru](https://l2db.ru/items/weapons/dagger/interlude).
- **Soul Separator**: A-grade dagger. P.Atk 203, M.Atk 114, price 27,000,000. Sources: [l2hub.info](https://l2hub.info/il/items/soul_separator), [l2db.ru](https://l2db.ru/items/weapons/dagger/interlude).

## A-grade bows

- **Carnage Bow**: A-grade bow. P.Atk 440, M.Atk 107, price 18,300,000. Sources: [l2hub.info](https://l2hub.info/il/items/carnage_bow), [l2db.ru](https://l2db.ru/items/weapons/bow/interlude).
- **Soul Bow**: A-grade bow. P.Atk 528, M.Atk 125, price 27,000,000. Sources: [l2hub.info](https://l2hub.info/il/items/soul_bow), [l2db.ru](https://l2db.ru/items/weapons/bow/interlude).

## A-grade polearms

- **Halberd**: ADDED. A-grade polearm. P.Atk 213, M.Atk 107, price 18,300,000. Tallum Glaive is P.Atk 232, M.Atk 114, price 27,000,000. Sources: [l2hub.info](https://l2hub.info/il/items/halberd), [github:Hl4p3x/L2JServer_C6_Interlude](https://github.com/Hl4p3x/L2JServer_C6_Interlude/tree/master/dist/game/data/stats/items).

## A-grade fist weapons

- **Blood Tornado**: ADDED. A-grade fist weapon. P.Atk 259, M.Atk 107, price 18,300,000. Dragon Grinder is P.Atk 282, M.Atk 114, price 27,000,000. Sources: [l2hub.info](https://l2hub.info/il/items/blood_tornado), [github:Hl4p3x/L2JServer_C6_Interlude](https://github.com/Hl4p3x/L2JServer_C6_Interlude/tree/master/dist/game/data/stats/items).

## A-grade weapons, uncertain

- **Sirra's Blade** **(uncertain: check again before use)**: A-grade in the client, L2J and l2hub. 1H, P.Atk 251, M.Atk 121. Rest of the series: Sword of Ipos (2H sword, 305/121), Barakiel's Axe (1H blunt, 251/121), Behemoth's Tuning Fork (2H blunt, 305/121), Naga Storm (dagger, 220/121), Shyeed's Bow (570/133), Themis' Tongue (1H sword, 202/161), Cabrio's Hand (1H blunt, 202/161), Tiphon's Spear (polearm, 251/121), Sobekk's Hurricane (fist, 305/121). Daimon Crystal (2H staff, P.Atk 245) has M.Atk 161 per L2J and 177 per l2hub, so that figure is unresolved. Prices disagree: 35,300,000 per aCis/L2J, 26,968,400 per l2hub, 0 per l2db.ru. How they are obtained was not established. Sources: [l2hub.info](https://l2hub.info/il/items/sirr_blade), [github:Hl4p3x/L2JServer_C6_Interlude](https://github.com/Hl4p3x/L2JServer_C6_Interlude/tree/master/dist/game/data/stats/items).

## S-grade swords

- **God's Blade**: S-grade, 1H. P.Atk 257, M.Atk 124. Not sold. Price 38,000,000 per L2J, aCis and l2hub, 48,800,000 per l2db.ru. Sources: [l2hub.info](https://l2hub.info/il/items/god's_blade), [l2db.ru](https://l2db.ru/items/weapons/sword/interlude).
- **Forgotten Blade**: S-grade, 1H. P.Atk 281, M.Atk 132, price 48,800,000. Sources: [l2hub.info](https://l2hub.info/il/items/forgotten_blade), [l2db.ru](https://l2db.ru/items/weapons/sword/interlude).
- **Heaven's Divider**: S-grade, 2H. P.Atk 342, M.Atk 132, price 48,800,000. Sources: [l2hub.info](https://l2hub.info/il/items/heaven's_divider), [l2db.ru](https://l2db.ru/items/weapons/sword/interlude).

## S-grade blunt weapons

- **Basalt Battlehammer**: S-grade, 1H. P.Atk 281, M.Atk 132, price 48,800,000. Yablonski's Hammer is 1H, P.Atk 251, M.Atk 121; price 35,300,000 per the datapacks and l2hub, 48,800,000 per l2db.ru. Sources: [l2hub.info](https://l2hub.info/il/items/basalt_battlehammer), [l2db.ru](https://l2db.ru/items/weapons/blunt/interlude).
- **Dragon Hunter Axe**: S-grade, 2H. P.Atk 342, M.Atk 132, price 48,800,000. Sources: [l2hub.info](https://l2hub.info/il/items/dragon_hunter_axe), [l2db.ru](https://l2db.ru/items/weapons/blunt/interlude).
- **Imperial Staff**: S-grade, 2H staff. P.Atk 274, M.Atk 175, price 48,800,000. The Staff is P.Atk 245, M.Atk 162, price 35,300,000 per the datapacks and l2hub. Arcana Mace is 1H, P.Atk 225, M.Atk 175, price 48,800,000. Sources: [l2hub.info](https://l2hub.info/il/items/imperial_staff), [l2db.ru](https://l2db.ru/items/weapons/blunt/interlude).

## S-grade daggers

- **Angel Slayer**: S-grade dagger. P.Atk 246, M.Atk 132, price 48,800,000. Dragon's Tooth is P.Atk 220, M.Atk 121, price 35,300,000 per the datapacks and l2hub. Sources: [l2hub.info](https://l2hub.info/il/items/angel_slayer), [l2db.ru](https://l2db.ru/items/weapons/dagger/interlude).

## S-grade bows

- **Shining Bow**: S-grade bow. P.Atk 581, M.Atk 132, price 48,800,000. Draconic Bow has the same stats and price. The Bow is P.Atk 519, M.Atk 121, price 35,300,000 per the datapacks and l2hub. Sources: [l2hub.info](https://l2hub.info/il/items/shining_bow), [l2db.ru](https://l2db.ru/items/weapons/bow/interlude).

## S-grade polearms and fist weapons

- **Saint Spear**: ADDED. S-grade polearm. P.Atk 281, M.Atk 132, price 48,800,000. Demon Splinter is the S-grade fist weapon: P.Atk 342, M.Atk 132, price 48,800,000. Sources: [l2hub.info](https://l2hub.info/il/items/saint_spear), [github:Hl4p3x/L2JServer_C6_Interlude](https://github.com/Hl4p3x/L2JServer_C6_Interlude/tree/master/dist/game/data/stats/items).

## S-grade Hero weapons

- **Infinity Blade**: S-grade hero weapons, not normal gear. Infinity Blade (1H sword) 297/137. Infinity Cleaver (2H sword) 361/137. Infinity Axe (1H blunt) 297/137. Infinity Rod (1H blunt) 238/182. Infinity Crusher (2H blunt) 361/137. Infinity Scepter (2H staff) 290/182. Infinity Stinger (dagger) 260/137. Infinity Bow 614/137. ADDED: Infinity Fang (fist) 361/137 and Infinity Spear (polearm) 297/137. Price 57,000,000 per the datapacks and l2hub, 48,800,000 per l2db.ru. Sources: [l2hub.info](https://l2hub.info/il/items/the_infinity_blade), [github:Hl4p3x/L2JServer_C6_Interlude](https://github.com/Hl4p3x/L2JServer_C6_Interlude/tree/master/dist/game/data/stats/items).

## No-grade armour

- **Wooden Breastplate**: No-grade light armour. Pieces (P.Def, price): Wooden Breastplate (47, 7,960), Wooden Gaiters (29, 4,970), Wooden Helmet (19, 3,980). Sold in V. The 'Wooden Set' bonus raises P.Def and MaxHP (l2hub). The exact figures (+2% P.Def, +41 HP) come from l2db.ru only. Sources: [l2hub.info](https://l2hub.info/il/items/wooden_breastplate), [l2db.ru](https://l2db.ru/items/sets/no/interlude/).
- **Tunic of Devotion**: No-grade robe. Pieces: Tunic of Devotion (30, 20,300), Stockings of Devotion (19, 12,700), Leather Helmet (23, 10,200). Sold in every V and T town plus Ivory Tower. Sources: [l2hub.info](https://l2hub.info/il/items/tunic_of_devotion), [l2db.ru](https://l2db.ru/items/sets/no/interlude/).

## D-grade heavy armour

- **Mithril Breastplate**: D-grade heavy armour, 'Mithril Heavy Armor Set' (bonus: resistance to poison). Pieces: Mithril Breastplate (95, 183,000), Mithril Gaiters (61, 127,000), Helmet (37, 76,200), Hoplon (shield, Sh.Def 128, 53,300). Breastplate and gaiters are sold in T. Helmet and Hoplon are sold in G5 plus Ivory Tower; l2hub also lists Woodley in Aden and Cema, while L2J does not list Woodley. Unrelated non-grade items ids 1309 and 1314 share the names Mithril Breastplate and Mithril Gaiters. Sources: [l2hub.info](https://l2hub.info/il/items/mithril_breastplate), [l2hub.info](https://l2hub.info/il/items/helmet/shops).
- **Brigandine Tunic**: D-grade heavy armour. Pieces: Brigandine Tunic (103, 299,000), Brigandine Gaiters (64, 187,000), Brigandine Helmet (41, 112,000), Brigandine Shield (Sh.Def 142, 78,400). Tunic and gaiters are sold in G5; l2hub also lists Woodley in Aden, which L2J and aCis do not. Helmet and shield are not sold. Sources: [l2hub.info](https://l2hub.info/il/items/brigandine/shops), [l2db.ru](https://l2db.ru/items/sets/d/interlude/).

## D-grade light armour

- **Reinforced Leather Shirt**: D-grade light armour. Pieces: Reinforced Leather Shirt (73, 152,000), Reinforced Leather Gaiters (46, 95,200), Reinforced Leather Boots (24, 50,800). Shirt and gaiters are sold in G5 (plus Aden per l2hub only). Boots are not sold. Sources: [l2hub.info](https://l2hub.info/il/items/reinforced_leather_shirt), [l2db.ru](https://l2db.ru/items/sets/d/interlude/).
- **Manticore Skin Shirt**: D-grade light armour. Pieces: Manticore Skin Shirt (77, 224,000), Manticore Skin Gaiters (48, 140,000), Manticore Skin Boots (27, 74,700). Shirt and gaiters are sold in G5 (plus Aden per l2hub only). Boots are not sold. Sources: [l2hub.info](https://l2hub.info/il/items/manticore_skin_shirt), [l2db.ru](https://l2db.ru/items/sets/d/interlude/).

## D-grade robes

- **Tunic of Knowledge**: D-grade robe. Pieces: Tunic of Knowledge (49, 152,000), Stockings of Knowledge (30, 95,200), Gloves of Knowledge (24, 50,800). Tunic and stockings are sold in T plus Ivory Tower. Gloves are not sold. Sources: [l2hub.info](https://l2hub.info/il/items/tunic_of_knowledge), [l2db.ru](https://l2db.ru/items/sets/d/interlude/).
- **Mithril Tunic**: D-grade robe, 'Elven Mithril Set' (bonus: speed, INT-1, WIT+1 per l2hub). Pieces: Mithril Tunic (52, 224,000), Mithril Stockings (32, 140,000), Elven Mithril Gloves (27, 74,700). Tunic and stockings are sold in G5 plus Ivory Tower. Gloves are not sold. Sources: [l2hub.info](https://l2hub.info/il/items/mithril_tunic/shops), [l2db.ru](https://l2db.ru/items/sets/d/interlude/).

## C-grade heavy armour

- **Chain Mail Shirt**: C-grade heavy armour. Pieces: Chain Mail Shirt (120, 505,000), Chain Gaiters (75, 316,000), Chain Hood (47, 189,000), Chain Shield (Sh.Def 166, 133,000). No C-grade armour is sold in shops. Sources: [l2hub.info](https://l2hub.info/il/items/chain_mail_shirt), [l2db.ru](https://l2db.ru/items/sets/c/interlude/).
- **Composite Armor**: C-grade heavy one-piece. Pieces: Composite Armor (224, 1,440,000), Composite Helmet (54, 368,000), Composite Shield (Sh.Def 190, 258,000). Sources: [l2hub.info](https://l2hub.info/il/items/composite_armor), [l2db.ru](https://l2db.ru/items/sets/c/interlude/).
- **Full Plate Armor**: C-grade heavy one-piece. Pieces: Full Plate Armor (239, 2,090,000), Full Plate Helmet (58, 536,000), Full Plate Shield (Sh.Def 203, 375,000). Sources: [l2hub.info](https://l2hub.info/il/items/full_plate_armor), [l2db.ru](https://l2db.ru/items/sets/c/interlude/).

## C-grade light armour

- **Mithril Shirt**: C-grade light armour. Pieces: Mithril Shirt (90, 379,000), Tempered Mithril Gaiters (56, 237,000), Mithril Boots (32, 126,000). Sources: [l2hub.info](https://l2hub.info/il/items/mithril_shirt), [l2db.ru](https://l2db.ru/items/sets/c/interlude/).
- **Plated Leather**: C-grade light armour. Pieces: Plated Leather (94, 446,000), Plated Leather Gaiters (59, 279,000), Plated Leather Boots (32, 126,000). Sources: [l2hub.info](https://l2hub.info/il/items/plated_leather), [l2db.ru](https://l2db.ru/items/sets/c/interlude/).
- **Theca Leather Armor**: C-grade light armour. Pieces: Theca Leather Armor (106, 825,000), Theca Leather Gaiters (66, 516,000), Theca Leather Boots (37, 275,000). Sources: [l2hub.info](https://l2hub.info/il/items/theca_leather_armor), [l2db.ru](https://l2db.ru/items/sets/c/interlude/).
- **Drake Leather Armor**: C-grade light one-piece. Pieces: Drake Leather Armor (179, 1,570,000), Drake Leather Boots (39, 358,000). Sources: [l2hub.info](https://l2hub.info/il/items/drake_leather_armor), [l2db.ru](https://l2db.ru/items/sets/c/interlude/).

## C-grade robes

- **Karmian Tunic**: C-grade robe. Pieces: Karmian Tunic (60, 379,000), Karmian Stockings (37, 237,000), Karmian Gloves (32, 126,000). Sources: [l2hub.info](https://l2hub.info/il/items/karmian_tunic), [l2db.ru](https://l2db.ru/items/sets/c/interlude/).
- **Demon's Tunic**: C-grade robe. Pieces: Demon's Tunic (69, 736,000), Demon's Stockings (43, 460,000), Demon's Gloves (36, 245,000). The set bonus lowers MaxHP and gives INT+4, WIT-1 (confirmed on l2hub). The -270 HP figure is from l2db.ru only. Sources: [l2hub.info](https://l2hub.info/il/items/demon's_tunic), [l2db.ru](https://l2db.ru/items/sets/c/interlude/).
- **Divine Tunic**: C-grade robe. Pieces: Divine Tunic (74, 1,070,000), Divine Stockings (46, 671,000), Divine Gloves (39, 358,000). Sources: [l2hub.info](https://l2hub.info/il/items/divine_tunic), [l2db.ru](https://l2db.ru/items/sets/c/interlude/).

## B-grade armour

- **Zubei's Breastplate**: B-grade Zubei sets. Heavy: Zubei's Breastplate (157, 2,080,000), Zubei's Gaiters (98, 1,300,000). Light: Zubei's Leather Shirt (117, 1,560,000), Zubei's Leather Gaiters (73, 973,000). Robe: Tunic of Zubei (78, 1,560,000), Stockings of Zubei (49, 973,000). All three share Zubei's Helmet (62, 778,000). Zubei's Gauntlets and Zubei's Boots are 41 P.Def each, 519,000, each in Heavy Armor, Light Armor and Robe versions. No B-grade armour is sold in shops. Sources: [l2hub.info](https://l2hub.info/il/items/shrnoen's_breastplate), [l2db.ru](https://l2db.ru/items/sets/b/interlude/).
- **Avadon Breastplate**: B-grade Avadon sets. Heavy: Avadon Breastplate (157, 2,080,000), Avadon Gaiters (98, 1,300,000), Avadon Shield (Sh.Def 216, 545,000). Light: Avadon Leather Armor (one-piece, 191, 2,280,000). Robe: Avadon Robe (one-piece, 127, 2,280,000). All share Avadon Circlet (62, 778,000). Avadon Gloves and Avadon Boots are 41 each, 519,000, in Heavy/Light/Robe versions. Sources: [l2hub.info](https://l2hub.info/il/items/avadon_breastplate), [l2db.ru](https://l2db.ru/items/sets/b/interlude/).
- **Blue Wolf Breastplate**: B-grade Blue Wolf sets. Heavy: Blue Wolf Breastplate (166, 3,220,000), Blue Wolf Gaiters (104, 2,010,000). Light: Blue Wolf Leather Armor (one-piece, 202, 3,530,000). Robe: Blue Wolf Tunic (83, 2,410,000), Blue Wolf Stockings (52, 1,510,000). All share Blue Wolf Helmet (66, 1,210,000). Blue Wolf Gloves and Blue Wolf Boots are 44 each, 804,000, in Heavy/Light/Robe versions. Sources: [l2hub.info](https://l2hub.info/il/items/blue_wolve's_breastplate), [l2db.ru](https://l2db.ru/items/sets/b/interlude/).
- **Doom Plate Armor**: B-grade Doom sets. Heavy: Doom Plate Armor (one-piece, 270, 4,710,000), Doom Shield (Sh.Def 230, 845,000). Light: Leather Armor of Doom (one-piece, 202, 3,530,000). Robe: Tunic of Doom (83, 2,410,000), Stockings of Doom (52, 1,510,000). All share Doom Helmet (66, 1,210,000). Doom Gloves are 44 P.Def, 804,000. CORRECTION: the boots are 'Doom Boots' only in the Heavy Armor/Light Armor/Robe versions. The plain item (id 601) is named 'Boots of Doom' (44, 804,000). Sources: [l2hub.info](https://l2hub.info/il/items/doom_boots), [l2db.ru](https://l2db.ru/items/sets/b/interlude/).

## A-grade armour

- **Dark Crystal Breastplate**: A-grade Dark Crystal sets. Heavy: Dark Crystal Breastplate (171, 4,630,000), Dark Crystal Gaiters (107, 2,890,000), Dark Crystal Shield (Sh.Def 243, 1,220,000). Light: Dark Crystal Leather Armor (128, 3,470,000), Dark Crystal Leggings (80, 2,170,000). Robe: Dark Crystal Robe (one-piece, 139, 5,080,000). All share Dark Crystal Helmet (69, 1,740,000). Dark Crystal Gloves and Dark Crystal Boots cost 1,160,000. They are P.Def 46 in the Heavy/Light/Robe versions and 45 as the plain items (ids 2472, 563). No A-grade armour is sold in shops. Sources: [l2hub.info](https://l2hub.info/il/items/dark_crystal_breastplate), [l2db.ru](https://l2db.ru/items/sets/a/interlude/).
- **Tallum Plate Armor**: A-grade Tallum sets. Heavy: Tallum Plate Armor (one-piece, 278, 6,770,000). Light: Tallum Leather Armor (one-piece, 209, 5,080,000). Robe: Tallum Tunic (86, 3,470,000), Tallum Stockings (53, 2,170,000). All share Tallum Helm (69, 1,740,000). Tallum Gloves and Tallum Boots cost 1,160,000; P.Def 46 in the Heavy/Light/Robe versions, 45 as the plain Tallum Gloves. Sources: [l2hub.info](https://l2hub.info/il/items/tallum_plate_armor), [l2db.ru](https://l2db.ru/items/sets/a/interlude/).
- **Armor of Nightmare**: A-grade Nightmare sets. Heavy: Armor of Nightmare (one-piece, 293, 10,300,000), Shield of Nightmare (Sh.Def 256, 1,850,000). Light: Nightmarish Leather Armor (one-piece, 220, 7,730,000). Robe: Nightmare Robe (one-piece, 147, 7,730,000). All share Helm of Nightmare (73, 2,640,000). Gauntlets of Nightmare and Boots of Nightmare cost 1,760,000; P.Def 49 in the Heavy/Light/Robe versions, 48 as the plain items. 'Nightmare Robe' and 'Nightmarish Leather Armor' are confirmed by l2hub's client-derived names. The datapacks' 'Robe of Nightmare' and 'Leather Armor of Nightmare' are server labels. Sources: [l2hub.info](https://l2hub.info/il/items/robe_of_nightmare), [github:cuteshaun/lineage2-api](https://github.com/cuteshaun/lineage2-api/blob/main/data/datapack/interlude/itemname-e.dat).
- **Majestic Plate Armor**: A-grade Majestic sets. Heavy: Majestic Plate Armor (one-piece, 293, 10,300,000). Light: Majestic Leather Armor (one-piece, 220, 7,730,000). Robe: Majestic Robe (one-piece, 147, 7,730,000). All share Majestic Circlet (73, 2,640,000). Majestic Gauntlets and Majestic Boots cost 1,760,000; P.Def 49 in the Heavy/Light/Robe versions, 48 as the plain items. Sources: [l2hub.info](https://l2hub.info/il/items/majestic_plate_armor), [l2db.ru](https://l2db.ru/items/sets/a/interlude/).

## S-grade heavy armour

- **Imperial Crusader Breastplate**: S-grade heavy armour. Pieces: Imperial Crusader Breastplate (205, 14,300,000), Imperial Crusader Gaiters (128, 8,960,000), Imperial Crusader Helmet (83, 5,370,000), Imperial Crusader Gauntlets (55, 3,580,000), Imperial Crusader Boots (55, 3,580,000), Imperial Crusader Shield (Sh.Def 290, 3,760,000). Sources: [l2hub.info](https://l2hub.info/il/items/imperial_crusader_armor), [l2db.ru](https://l2db.ru/items/sets/_/interlude).

## S-grade light armour

- **Draconic Leather Armor**: S-grade light one-piece. Pieces: Draconic Leather Armor (249, 17,400,000), Draconic Leather Helmet (83, 5,370,000), Draconic Leather Gloves (55, 3,580,000), Draconic Leather Boots (55, 3,580,000). Sources: [l2hub.info](https://l2hub.info/il/items/draconic_leather_armor), [l2db.ru](https://l2db.ru/items/sets/_/interlude).

## S-grade robes

- **Major Arcana Robe**: S-grade robe, one-piece. Pieces: Major Arcana Robe (166, 17,400,000), Major Arcana Circlet (83, 5,370,000), Major Arcana Gloves (55, 3,580,000), Major Arcana Boots (55, 3,580,000). Sources: [l2hub.info](https://l2hub.info/il/items/major_arcana_robe), [l2db.ru](https://l2db.ru/items/sets/_/interlude).

## Item names

- **Scroll: Enchant Weapon (Grade D)**: Confirmed spellings: Scroll: Enchant Weapon (Grade D/C/B/A/S) and Scroll: Enchant Armor (Grade D/C/B/A/S). Shots: 'Soulshot: No Grade', 'Soulshot: D-grade' through 'Soulshot: S-grade', and 'Spiritshot: No Grade', 'Spiritshot: D-grade' and so on. Blessed spiritshots use a capital G ('Blessed Spiritshot: D-Grade') except 'Blessed Spiritshot: S Grade', which has no hyphen. Sources: [l2hub.info](https://l2hub.info/il/items/scrl_of_ench_wp_d), [l2hub.info](https://l2hub.info/il/items/soulshot_d), [github:cuteshaun/lineage2-api](https://github.com/cuteshaun/lineage2-api/blob/main/data/datapack/interlude/itemname-e.dat).

## Disputes and caveats

What the checks could not settle, kept as the checker wrote it.

- dropped: Blade of Serenity, Mist Sword, Sword of Desert, Dusk Sword, Eminence Sword, Hazard Sword (all removed from the Keshanberk entry). They exist as item ids 136-141 in the datapack/client table with Keshanberk's stats, but l2hub has no page for any of them in any chronicle, and no drop, craft or shop was found. Do not offer them as obtainable B-grade swords.
- CORRECTION: Morning Star. The researcher said no shop sells it. l2hub lists 14 T-town traders (Giran, Oren, Dion, Gludin, Schuttgart, Rune, Goddard, Gludio, Heine, Hunters Village, Aden), while L2J and aCis give it only to the GM shop. Unresolved.
- CORRECTION: Aden's armour trader Woodley (npc 30838). l2hub lists him selling the mid-D armour (Brigandine, Reinforced Leather and Manticore Skin shirts/gaiters, Helmet, Hoplon). L2J and aCis give him only the low tier. The researcher's 'Aden does not sell mid-tier D' holds for weapons in every source but is disputed for armour.
- Price conflict, a pattern across sources. For the weapons added in C5/Interlude (ids 7881-7902 and the 86xx series), l2hub's reference prices are about 0.77x the L2J/l2db.ru figures: Titan Sword 1,074,000 vs 1,400,000; Pa'agrian Sword 3,304,300 vs 4,300,000; Guardian Sword 10,091,400 vs 13,100,000; Infernal Master 14,098,000 vs 18,300,000; Sirra series 26,968,400 vs 35,300,000. aCis gives a third set again (e.g. 1,396,200). The entries keep the L2J/l2db.ru figure and note the conflict. Stats agree in every source.
- Daimon Crystal M.Atk: 161 per L2J, 177 per l2hub. Unresolved. Branch of The Mother Tree M.Atk is 152 per L2J and l2hub, but one other datapack copy says 167.
- Rune Township's traders (Drumond, Nils, Vladimir, Alisha; npc 31300-31303) have no town label on l2hub. Their Rune placement comes from the L2J npc ids and the researcher's spawn-coordinate method, so G5 still includes Rune.
- Town name spelling is unresolved. l2hub writes 'Hunter Village' while the researcher wrote 'Hunters Village' from lineage2-api. Neither was checked against the client's zonename-e.dat.
- Duplicate item names exist and can mislead lookups. Bastard Sword (id 1297), Great Sword (1299), Mithril Breastplate (1309), Mithril Gaiters (1314) and Bec de Corbin are also names of non-grade 'kamex' items with different stats. Use the graded ids (69, 78, 58, 59).
- A/B gloves and boots exist as plain items (e.g. Dark Crystal Gloves id 2472, P.Def 45; Gauntlets of Nightmare 2479, P.Def 48), as 'Sealed ...' items, and as '- Heavy Armor / - Light Armor / - Robe' versions (P.Def 46 / 49). The plain Doom boots are 'Boots of Doom'; only the versions are 'Doom Boots'. How the in-game tooltip renders the name together with the additional name was not confirmed.
- Added polearm and fist-weapon entries (Short Spear, Long Spear, Trident, Pike, Dwarven Trident, Winged Spear, Glaive, Scythe and the C/B/A/S poles; Cestus, Bich'Hwa, Scallop Jamadhr, Chakram, Knuckle Duster, Great Pata, Arthro Nail, Bellion Cestus, Blood Tornado, Dragon Grinder, Demon Splinter; Infinity Fang and Infinity Spear). The original set had no polearms or fists. Each was confirmed by l2hub and the L2J XML; shops come from l2hub only.
- Shop lists are now cross-checked against l2hub, which is independent of the L2J/aCis buylists, for every no-grade and D-grade item listed. They agree except Morning Star and Woodley/Aden (above). Cema (Magic Trader) has no town on l2hub either, so her location is still unconfirmed.
- Set-bonus magnitudes are still single-source (l2db.ru): Wooden +2% P.Def/+41 HP and Demon -270 HP. l2hub confirms only the direction (Wooden raises P.Def and MaxHP; Demon lowers MaxHP with INT+4, WIT-1).
- How much the sources overlap: l2hub is client/PTS-derived and l2db.ru is independent of it; L2J, aCis and the second L2J Interlude pack share one lineage. Every 'confirmed-2-sources' entry here has l2hub plus at least one of L2J or l2db.ru.
- L2Wiki, lineage2.fandom, Linedia and l2central were not consulted in this pass.
