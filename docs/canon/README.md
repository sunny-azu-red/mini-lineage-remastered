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
| [towns.md](towns.md) | Every town's NPCs, every Gatekeeper's destinations and fees, temples and village masters, the four villages' guilds and trainers, the Newbie Guide and its buffs |
| [monsters.md](monsters.md) | Every monster around the four villages and on Ruins of Despair: L2J's full stat block, EXP, SP and Adena, how a monster's Accuracy, Evasion and Critical are worked out, and the spells monsters cast |
| [hunting-grounds.md](hunting-grounds.md) | Every hunting ground: nearest town, teleport fee, level band, monsters by level |
| [weapons-and-armour.md](weapons-and-armour.md) | Every weapon and armour piece by grade and type: stats, reference price, which towns sell it |
| [inventory.md](inventory.md) | Every equipment slot, a naked character's stats and how gear replaces them, the inventory's limits, and everything the four starting villages' traders sell, with prices |
| [jewellery-and-consumables.md](jewellery-and-consumables.md) | Jewellery by grade, epic jewels, potions, scrolls, soulshots and spiritshots, enchanting |
| [skills.md](skills.md) | Each base set's skills from level 1 to 20, the first skills' numbers, how blows, drains, damage over time and misses resolve, the EXP penalty against weaker monsters, and the Monument of Heroes |
| [movement.md](movement.md) | How far everything reaches and how fast it moves: every monster's attack range, run speed and aggression, every spell's and weapon's range, the starting classes' run speed, the slows, and how aggressive and passive monsters engage |
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
- **A class is changed only in the character's own starting village,** by that village's master
  (High Priest Biotin, Hierarch Asterios, Tetrarch Thifiell, Flame Lord Kakai). In Lineage II any
  town's master would do.

**Skills**

Every skill, its numbers and its level come from the set's own canon tree (rules §19, §25), but for
the Orc Mystic's Chill Flame. What differs is which of them a set gets, how they are sold, and how
the fight uses them.

- **Each set plays its own way.** Before the class change a set learns its first skill, two to
  four more from its tree and four masteries, chosen so no two sets fight alike, where Lineage II's trees are far
  larger and shared:

  | Set | Its style | Its skills |
  |---|---|---|
  | Human Fighter | the all-rounder, a line for every weapon and no recovery | Power Strike, Mortal Blow, Power Shot |
  | Elven Fighter | the archer who guards | Power Shot, Defense Aura, Elemental Heal |
  | Dark Fighter | the dagger who strikes harder | Mortal Blow, Attack Aura, Drain Health |
  | Orc Fighter | fists and sword, and the one Fighter that rests faster | Iron Punch, Power Strike, Relax |
  | Human Mystic | wind and ice | Wind Strike, Self Heal, Ice Bolt |
  | Elven Mystic | the healer | Wind Strike, Self Heal, Ice Bolt, Heal |
  | Dark Mystic | drains and curses | Wind Strike, Self Heal, Vampiric Touch, Curse: Poison, Shield, Wind Shackle |
  | Orc Mystic | burns, drains and spirit | Chill Flame, Soul Cry, Life Drain, Soul Shield |

  So **the Elven Fighter learns only Defense Aura and the Dark Fighter only Attack Aura**, where
  Lineage II taught both to both; **Relax is the Orc Fighter's alone**, where Lineage II also gave
  it to the Human Fighter; and **the Orc Mystic has no Venom**: a poison only pays while the spells
  rest, the Orc Mystic's never do, and cast first it slowed the set by a fifth (`docs/balance.md`).
- **The Orc Mystic knows Chill Flame from level 1,** where Lineage II taught it at 7, with an
  amulet, and the Orc Mystic fought with Soul Cry and its weapon until then. Played that way it died
  at levels 2 to 7 even resting to full (`docs/balance.md`).
- **A Fighter starts knowing the skill of the weapon it starts with, and its weapon skills begin at
  level 1,** where Lineage II taught them from 5: the first level of each at level 1, its own first
  skill for nothing and any other for 50 SP, and the rest of that tier at 5. A Mystic starts
  knowing its first spell, as in Lineage II, and could not do without it: made to buy it at level 1
  for 50 SP, nine Mystic runs in ten died at levels 1 to 3 before they could.
- **A Mystic's second skill at level 1 costs 50 SP** (Self Heal, or the Orc's Soul Cry), where
  Lineage II gave it free.
- **A skill grows in steps, not nine levels:** the canon levels taught at one character level are
  one line, at the top level's power and MP, so no two lines of one skill open at the same level and
  Power Strike has 4 lines where Lineage II sold 9 one at a time. Only a Fighter's weapon skills keep
  their first level apart, at level 1.
- **Four masteries a path before the class change, and every Mystic's armour one is Robe
  Mastery.** A Fighter learns Armor Mastery (142) and Weapon Mastery (141) as Lineage II teaches
  them, and a Mystic Weapon Mastery (249, the Orc Mystic's 250) and Anti Magic (146): one name for
  the Fighter's Weapon Mastery and the Mystic's, each its own lines, as in Lineage II, whose bow and
  polearm penalty never applies, since a Mystic is sold neither. Every Mystic learns Robe Mastery
  (251), which Lineage II gives only the Orc Mystic: the Human, Elven and Dark Mystics' Armor
  Mastery (244) adds half as much on any armour, and a Mystic only ever wears a robe. Robe Mastery 1
  costs the Orc Mystic's 520 SP for every Mystic, and Robe Mastery 2 costs 6,800 where Lineage II
  asks 1,760, so a Mystic reaches level 20 with about the SP a Fighter has left. A Fighter learns
  Anti Magic too, which Lineage II teaches only Mystics, at levels 5 and 10 for what its race's
  Mystic pays: the Orc Fighter's ground has the Evil Eyes' spells, and the grounds past the villages
  cast more. Every other line costs what Lineage II asks for the levels it holds, where the late
  lines once cost more to soak up the SP the masteries took; what is left after level 15 waits for
  the class change.
- **Buffs are cast on oneself.** Shield and Soul Shield, cast on a target in Lineage II, are cast
  by the Mystic on itself, as a lone Mystic did there. **An aura holds 2 minutes,** out of the
  fight too, where Lineage II's held 20: a fight here lasts seconds, so 20 minutes was every fight
  of a sitting on one cast.
- **The character chooses its own skills in a fight** (rules §20): its toggle, its strongest spell,
  then while its spells rest its strongest heal below the player's share of HP, or a curse on a
  monster above half its HP, and before the pull its auras, then its heals up to that share. A Mystic
  lights Soul Cry only once its blows reach. In Lineage II the player chose each cast; here the
  player gives orders, and may leave any skill but a heal unused. Life Drain, which returns 80% of
  what it deals, is cast only below 85% of HP, as the heal it mostly is: cast whenever ready, its
  27 MP a cast kept the Orc Mystic the slowest set (`docs/balance.md`).
- **A slow caster casts its spell whenever it is ready** (rules §20): the golems, the zombies and the
  Undead Slave, whose Lineage II AI (`WarriorSlowType`) cast mostly at a target not hitting them.
  Their spell is a power-5 poke, and Lineage II's odds moved no set by more than 1%
  (`docs/balance.md`).
- **A fight is fought on one line** (rules §20): the character pulls from its opening's reach, or an
  aggressive monster comes at it from L2J's 500, the monster runs in at L2J's run speed (which holds
  its DEX bonus), and once both are in reach nobody moves again, so nobody kites, flanks or chases.
  A clan never comes to a member's help. A passive monster wakes at the first blow, shot or spell,
  and a spell takes effect as its cast ends, as in Lineage II. **Ice Bolt slows both swing and run** by 30%, where
  Lineage II slowed only the run (`movement.md`), since a monster that has run in is held off only
  by its swing: slowing the run alone, the Elven Mystic resting at half without potions died at
  level 19 in most runs (`docs/balance.md`).
- **Odds and numbers are fixed where Lineage II rolled against stats we lack.** A heal mends its
  power + √M.Atk, as aCis has it and every retail-derived source shows; L2J heals its power alone.
  Curse: Poison lands 70% of the time, aCis's power, where L2J rolls against the target's
  CON and M.Def. Wind Shackle lands 80%, with no MEN save.
- **Relax works on the tick of rest,** 5 HP more for 3 MP, while HP is short. In Lineage II it sat
  the character down, drained 2 MP every 2 seconds and ended when it stood or HP was full.
- **Soul Cry lasts one fight** and is lit anew in the next, where Lineage II kept it on until
  switched off.
- **The Orc Mystic's Chill Flame can take the last HP,** where Lineage II's leaves 1: its first
  spell is a burn whose cast outlasts it, so without that it paid for every kill in blows taken.
- **Skills are learned with level and SP alone, at the trainers of the character's own village.**
  In Lineage II some needed a spellbook from the village trader, and any town's trainers for your
  race would teach you.
- **The guilds are named alike in both villages that have two:** Warriors Guild and Mystics Guild,
  with no apostrophe. Lineage II's Newbie Guide writes "Warriors' Guild" and "Temple (Mystics'
  Guild)" in Talking Island but "Warrior Guild" and "Mystic Guild" in the Orc Village.

**Pace and gear**

- **The server runs at rates** (rules §22): EXP and SP ×5, Adena ×20. Retail Interlude ran at ×1;
  private servers ran at rates like these. Adena runs faster than EXP because the hunt has no quests
  and no drops to sell, which is where most of Lineage II's Adena came from.
- **Armour is three pieces: chest, legs and necklace,** beside the weapon and the shield. Each
  stands for its whole part (the chest for head, chest and gloves; the legs for legs and feet; the
  necklace for all five pieces of jewellery), counting its canon defence × its part's share ÷ its
  slot's (rules §7), so a three-piece set is as strong as the matching full set. It costs its canon
  price by the same share (rules §24), so a Necklace of Wisdom is 37,531 where Lineage II's necklace,
  two earrings and two rings of its grade came to about 41,500. Helmets, gloves, boots, earrings and
  rings are not sold.
- **A potion heals its whole amount at once, with no reuse,** drunk by the character itself below the
  share of HP its player chose, one a round (rules §26). In Lineage II a Lesser Healing Potion
  healed 16 HP every 2 seconds for 15 seconds (112 in all) and rested 10 seconds; it is kept at its
  canon 112 and its base price, 90, with no tax.
- **The villages sell only the Lesser Healing Potion,** as in Lineage II; better potions and potions
  for MP wait for the towns further on, where Lineage II sold the Healing Potion (Gludio) and no NPC
  sold a Mana Potion at all.
- **Five kinds of weapon: sword, dagger, bow, fists and staff** (rules §23). The no-grade blunts
  (Club, Mace, Heavy Chisel, Sickle, Dwarven Mace) and the Short Spear are not sold; dual swords
  and polearms never come. A two-handed sword (BIGSWORD) is a sword, and every mystic weapon is a
  staff: the two-handed staves (BIGBLUNT), and one-handed the Apprentice's Wand (BLUNT) and
  the book, horn and relic (ETC). Each keeps its canon numbers. So Power Strike takes a sword in
  either hand, where Lineage II also took a blunt, a two-handed blunt and so a staff.
- **Bows need no arrows.** In Lineage II every shot spent one, a miss included; here a bow only
  draws and reloads (rules §10).
- **A weapon's spread covers every physical hit it makes,** skills and blows included, as aCis does;
  L2J spread normal attacks by 0 to +10% whatever the weapon. A monster's blows spread ±10%.
- **A fighter's kit carries a Squire's weapon for each skill its trainer teaches that needs one,**
  so every first skill works from the first fight and a Human Fighter can start down any of its
  three paths: the Human Fighter a Squire's Sword, Dagger and Bow, the Orc Fighter Squire's Gloves and
  a Squire's Sword, the Elven Fighter a Squire's Bow, the Dark Fighter a Squire's Dagger. In Lineage
  II all three Fighters carried a Squire's Sword and a Dagger. The Dagger is renamed Squire's Dagger,
  and the Squire's Bow is ours (P.Atk 14, M.Atk 5, price 138): the Short Bow less what the Squire's
  Sword is below the Short Sword, so that no shop sells anything in a kit.
- **Every kit is a squire's or an apprentice's, and nothing else is.** Lineage II's Training Gloves
  are Squire's Gloves and its Apprentice's Spellbook the Scholar's Tome, each with its numbers, so
  every fighter's kit reads alike, as every mystic's does, and no shop sells an apprentice's thing.
- **The Orc Mystic starts with the Apprentice's Wand,** as every other mystic does, where Lineage II
  gave it Training Gloves and no wand. Its spells draw on M.Atk, which the wand has more of (7
  against 5), and a shop shows a mystic staves and never fists (rules §24).
- **A village shop sells one of each kind at each price,** where Lineage II sold twins with the same
  numbers under two names: the Doom Dagger beside the Knife, the Orcish and Handmade Swords beside
  the Gladius, the Apprentice's Rod beside Buffalo's Horn, the Cotton Shirt and Pants beside the
  Bone Breastplate and Gaiters, the Hard Leather Pants beside the Wooden Gaiters, and the Feriotic
  Tunic and Stockings beside the Cotton ones. The first of each is not in the game.
- **A shield blocks from any side, and never a spell.** Lineage II blocked only blows from the front,
  three times as often against arrows, and aCis let a shield turn spells too.
- **A character carries 15 items, and nothing is weighed.** Lineage II gave every non-Dwarf 80
  inventory slots and a weight limit with load penalties. A text game has no use for weight, and 15
  makes outgrown gear go to the trader rather than pile up. As in Lineage II, what is worn counts and
  a potion's stack takes one place.

**Trade**

- **A trader shows each path only its own goods** (rules §24): a fighter the weapons its own skills
  use, light armour and shields; a mystic staves, robes and shields; both the jewellery and the
  potions. In Lineage II every trader showed both a fighter's list and a mystic's to anyone.
- **The jeweller and the grocer share one counter, the Magic Trader** (rules §24), its jewellery
  and potions on one page with both keepers greeting you. In Lineage II each kept a shop window of
  their own, though the Newbie Guide already named their building the Magic Trader.
- **The Weapon Trader is singular,** as the Armour Trader and the Magic Trader are, and so is its
  address (`/traders/weapon`). Lineage II wrote "Weapons Trader" beside "Armor Trader" (Giran's
  titles, the Newbie Guide's building), a quirk kept nowhere else.
- **Shops charge an item's canon price, with no castle tax** (Lineage II added the castle lord's
  tax, 15% in a village), and nothing mentions one.
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
