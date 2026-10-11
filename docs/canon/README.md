# The Lineage II canon

**This is the reference, not a roadmap.** It records what the real game had in Interlude (C6):
names, numbers, places, monsters, items, buffs and fees, each checked against at least two
sources. Being listed here means it existed in Lineage II, not that Mini-Lineage will have it. What
gets built, and when, is in [../roadmap.md](../roadmap.md). How it works once built is in
[../rules.md](../rules.md).

## The rule

**No player-facing Lineage II name or number enters the game unless it is here.** That covers
`docs/rules.md`, `Rules`, narrative pools and templates. If something you need is missing, research
it and add it here first. Never guess it, approximate it or invent a plausible one.

- **The chronicle is Interlude.** A later or earlier chronicle's value is not canon, even when it is
  easier to find.
- **Spell it as the entry does,** quirks included ("Soulshot: D-grade", "Blessed Spiritshot:
  D-Grade", "Hunters Village").
- **From here to the game,** a number is taken whole into `docs/rules.md` when a rule is written,
  and never rescaled beside numbers that were not. From then on the rule is the authority, and
  `rules_test.exs` holds the code to it.
- **A deliberate departure is listed below** before it is built. Anything else that differs from
  this file is a bug in one of the two.

## How far to trust an entry

- **No mark:** confirmed by two sources, at least one outside the L2J family where the topic
  allowed it.
- **(single source):** one source only. Usable, but say so in the rule that uses it.
- **(uncertain: check again before use):** found, but not confirmed. Check it again before anything
  depends on it.
- **Disputes and caveats,** at the end of each file, are what the checks could not settle: price
  disagreements between datapacks, label variants, levels that differ by source. Pick one value,
  say which source it came from in the rule, and keep it.

The sources are Interlude datapacks (L2J C6, aCis, L2J Mobius CT_0, the PTS AI port in
dr3dd/L2Interlude) and item databases (l2hub.info/il, l2db.ru). The L2J packs share one lineage, so
two of them together count as less than two independent sources. The fandom wiki, L2Wiki and
Linedia were not reachable when this was checked.

The formulas behind rules §4 to §11 come from L2J Mobius CT_0 Interlude
(`mechanics/stats/Formulas.java` and `data/stats/statBonus.xml`), simplified.

## What is here

| File | Holds |
|---|---|
| [races.md](races.md) | Each race's level-1 template (attributes, HP, MP, speed) and every starting set's gear |
| [towns.md](towns.md) | Every town's NPCs, every Gatekeeper's destinations and fees, temples and village masters, the Newbie Guide and its buffs |
| [monsters.md](monsters.md) | Every monster around the four villages and on Ruins of Despair: L2J's full stat block, EXP, SP and Adena, how a monster's Accuracy, Evasion and Critical are worked out, and the spells monsters cast |
| [hunting-grounds.md](hunting-grounds.md) | Every hunting ground: nearest town, teleport fee, level band, monsters by level |
| [weapons-and-armour.md](weapons-and-armour.md) | Every weapon and armour piece by grade and type: stats, reference price, which towns sell it |
| [inventory.md](inventory.md) | Every equipment slot, a naked character's stats and how gear replaces them, the inventory's limits, and everything the four starting villages' traders sell, with prices |
| [jewellery-and-consumables.md](jewellery-and-consumables.md) | Jewellery by grade, epic jewels, potions, scrolls, soulshots and spiritshots, enchanting |
| [skills.md](skills.md) | Each base set's skills from level 1 to 20, the first skills' numbers, how blows, drains, damage over time and misses resolve, the EXP penalty against weaker monsters, and the Monument of Heroes |
| [bosses-and-buffs.md](bosses-and-buffs.md) | Grand and raid bosses with levels and lairs, buffs, chants and debuffs with the classes that cast them |

## Not researched yet

Each of these must be added here before the system that needs it is written into the rules.

- **Monster stats past Ruins of Despair:** `monsters.md` covers the four villages' grounds and
  Gludio's first; every later ground needs its monsters added before it opens.
- **Skills past level 20:** each class's skills after its transfer.
- **The class tree:** every class by race and path, the levels at which each transfer happens,
  who performs it and what it asks, and each class's HP and MP growth.
- **Armour set bonuses** beyond the two noted in `weapons-and-armour.md`.
- **Private stores:** how a player's sell and buy store works (what it can list, how many lines).
- **Crystals and shots:** crystallizing gear, the soulshot and spiritshot recipes by grade, what
  they ask, and which bosses and places drop them.
- **Drops:** which monster drops which item.

## Deliberate departures

Where Mini-Lineage knowingly differs from the real game. Each keeps its real names and numbers
where it has any.

**The world**

- **Four races.** No Dwarves, so no Dwarven Village and no crafting race.
- **Travel is by Gatekeeper only.** Walking between towns is impossible in a text game.
- **No Gludin Village and no boats.** Every starting village sends a character straight to the
  Town of Gludio, and the villages never link to each other. In Lineage II, Talking Island reached
  the mainland by ship to Gludin Harbor, and every village had a Gatekeeper route to the others.
- **The Gatekeeper fees are the game's own** (rules §14), to be tuned once the balance can be seen.
  In Lineage II nobody had to pay a village's 9,200 to 23,000 Adena to Gludio, because walking and
  the boat were free.
- **Giran Harbor is reached from Dion.** In Lineage II it hung off Giran, for 5,200.
- **Night and the race perks are simplified** (rules §15 and §16). Interlude's servers do make
  night harder to hit in, but by far more than our Accuracy −3. Shadow Sense is the Dark Fighter's
  real passive (id 294, +3 Accuracy at night), learned at level 15; ours is every Dark Elf's from
  level 1. The Blessing of the Mother Tree is ours alone.
- **A hunt never meets a monster above the character's level** (rules §20). In Lineage II a player
  chose whom to fight; here the ground chooses, so it chooses nothing stronger.
- **Each village has one hunting ground,** a ladder from level 1 to the level where Gludio takes
  over. It carries one nostalgic name (Obelisk of Victory, Elven Fortress, School of Dark Arts,
  Cave of Trials) and draws on every monster around that village: its fields and its nearby named
  grounds. Each monster keeps its own level and stats.

**Characters**

- **Death is final.** The run ends and the character is kept in the highscores, ranked by level
  and then EXP. In Lineage II death cost EXP and you got up again. Mini-Lineage is a game you
  replay for a better score.
- **"Orc Mystic"** names the Orc's mystic set, matching the other three Mystics, even if the
  client says "Orc Mage".
- **Every set starts with one skill from its own tree, and each race's differs:** Power Strike
  (Human Fighter), Power Shot (Elven Fighter), Mortal Blow (Dark Fighter), Iron Punch (Orc
  Fighter), Wind Strike (Human Mystic), Ice Bolt (Elven Mystic), Vampiric Touch (Dark Mystic),
  Chill Flame (Orc Mystic). In Lineage II only Wind Strike and Soul Cry came at level 1, the
  Fighters' skills came at 5, and each needed the right weapon.
- **A short skill list per set,** different for each race, until the class change opens the
  specialised skills. Lineage II's trees are far larger.
- **No spellbooks.** A line is learned with level and SP alone; in Lineage II some needed a book
  from the village trader.
- **Skills are learned only at the trainers of the character's own village,** with SP. In
  Lineage II any town's trainers for your race would teach you.
- **A class is changed only in the character's own starting village,** by that village's master
  (High Priest Biotin, Hierarch Asterios, Tetrarch Thifiell, Flame Lord Kakai). In Lineage II any
  town's master would do.

**Pace and gear**

- **The server runs at rates** (rules §22): EXP and SP ×5, Adena ×20. Retail Interlude ran at ×1;
  private servers ran at rates like these. Adena runs faster than EXP because the hunt has no quests
  and no drops to sell, which is where most of Lineage II's Adena came from.
- **The inventory keeps only the combat slots:** weapon, shield, head, chest, legs, gloves, feet,
  necklace, two earrings and two rings. No underwear, face or hair slots.
- **Bows need no arrows.** In Lineage II every shot spent one, a miss included; here a bow only
  draws and reloads (rules §10).
- **Weapons keep their speed and critical but not their accuracy or damage spread.** Every blow
  spreads ±10% (rules §13), and a Dagger's −3 Accuracy or a staff's +4 is left out.
- **The Elven Fighter's kit carries a Short Bow in place of the Dagger,** so its Power Shot works from
  the first fight.
- **A shield blocks from any side, and never a spell.** Lineage II blocked only blows from the front,
  three times as often against arrows, and aCis let a shield turn spells too.
- **The inventory counts items and does not weigh them:** 80 slots, as for every non-Dwarf, with no
  weight limit and no load penalties.

**Trade**

- **NPC shops sell better gear in more advanced towns, for more money.** In Lineage II no NPC
  sold anything above D-grade; C-grade and better came from crafting, drops and players.
- **Buffs are bought in towns,** at the Temple in each, with more of them further on. In Lineage II
  no priest sold or cast buffs; they came from players. The buffs sold keep their real names and
  strengths. The villages keep the Newbie Guide's free buffs, as in Lineage II.
- **Soulshots and spiritshots are sold only in player shops.** In Lineage II any grocer sold them.
  They are crafted from crystals, with a recipe per grade that drops only from bosses and special
  places; in Lineage II the Dwarves crafted them.
- **A player shop stays open while its owner is away.** The character sits in that town, as in
  Lineage II, and can't hunt or travel until it closes, but in Lineage II the player had to stay
  logged in.
