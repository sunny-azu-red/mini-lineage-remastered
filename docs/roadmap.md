# Mini-Lineage: the roadmap

What gets built on top of the base rules (`docs/rules.md`), one system at a time. These are ideas
raised so far, not promises. When a system is picked up, its rules are written into `rules.md`
first, and the code follows.

**Where names and numbers come from.** Every Lineage II name and number in a system comes from the
canon in [canon/README.md](canon/README.md), which is the reference, not a plan. If the canon
doesn't have it, it is researched and added there before the rule is written. Where the game
departs from Lineage II on purpose, the canon lists the departure.

**Mini, on purpose.** Every system is a simplified version of the real one: a few skills rather
than a tree, one ground per village rather than six. The names, places, monsters and items are
what bring Lineage II back; the systems stay small enough to be fun.

**Old mechanics.** What the game was before the base layer is kept in `legacy/`, to read and never
to run. Rebuilt so far, each on the base layer: the shops (the traders), the Battleground (the
hunting grounds), the Character page, the Hall of Champions (the Monument of Heroes), timed buffs
(the auras), and the level-up's and the death's sounds. Still only there: the Inn, a run's
Chronicle, the Tome, the Class Master, the Symbol Maker, the Konami cheat, and the critical hit's,
the coin's and the food's sounds. Each comes back as its system below, and nothing from `legacy/`
comes back as it was.

**Where the content goes.** A system's tables start in `Rules` beside the base layer's, held to
`rules.md` by `rules_test.exs`. When one grows into the hundreds it moves to a data file under
`priv/` loaded at compile time, still in git, as the monsters, the items and the trainers' lessons
have (`priv/game/*.csv`); it goes into Postgres only if it
must change without a deploy. Postgres is for what grows with play, which includes every
character's inventory and every player shop. AGENTS.md has the reasoning.

## A new player's road

You spawn in your village, you fight, you earn Adena, you buy something better, and when your
village's ground has nothing left to teach you, you pay the Gatekeeper to Gludio. There the
monsters are harder and the rewards bigger, and later towns sell stronger gear and buffs to help you
win. It has to be easy to understand from the first click.

## Why a character travels

The starting grounds stop being worth anything after the first twenty levels, so every place has
to keep a reason to be visited. Each system below gives one.

- **The home village is where a character grows.** Its trainers teach the character's skills for
  SP, and its master changes its class at 20, 40 and 76, so a character comes home however far it
  has gone. The village also has the Newbie Guide's free buffs until level 25, and the no-grade
  shops.
- **Towns are where the buying is.** The Temple sells buffs, which no village does, with more of
  them further on. Each town's shops sell better gear than the last, for more money.
- **Player shops are where the rest is.** Every soulshot and spiritshot comes from another player,
  in whichever town they chose to open.
- **The hunting grounds climb with the towns.** Each ground sits by one town at its own level band,
  so a character's grounds move outward as it levels, from its village to Gludio, Dion, Giran and
  beyond.
- **Travel costs Adena,** so every trip is a decision.

## The first hunt

Built (rules §17 to §21), with the canon's monster stats researched first.

- **One ground per village,** a ladder from level 1 to the level where Gludio takes over, under
  one nostalgic name. It draws on every monster around that village, each at its own level and
  stats:

  | Village | Ground | Monsters from | Levels |
  |---|---|---|---|
  | Talking Island Village | Obelisk of Victory | its fields, Eastern Territory, the Obelisk, Singing Waterfall | 1–17 |
  | Elven Village | Elven Fortress | its fields, the Fortress | 1–20 |
  | Dark Elf Village | School of Dark Arts | its fields, Dark Forest, the School | 1–22 |
  | Orc Village | Cave of Trials | its fields, Immortal Plateau (north), the Cave | 1–21 |

- **A ground is reached on foot from its village,** for free.
- **One click, one fight:** a monster near the character's level, fought to the end in rounds,
  with blows at Atk. Spd., spells at Casting Spd. and the skills it has learned, as its battle
  orders say. It pays EXP, SP and Adena.
- **It can kill.** There is no warning but the sidebar's HP or MP row pulsing under a quarter.
- **Next, Gludio:** Ruins of Despair, levels 15 to 24.

## Built with the first hunt

The hunt (rules §17 to §21) put the base layer to work: EXP and levelling (§12) with the level-up
told, the base outcomes (§13), SP, death and the Monument of Heroes. Being in combat (§11) holds
on the ground, as the legacy Battleground did, and lifts five seconds after leaving it, counted down
over its icon as the legacy game counted its effects.

**It ships with the inventory and the village shops.** A seeded run of the first hunt showed that a
character without gear dies in most fights by level 10, because Lineage II's monsters assume a
weapon and armour, while the canon's no-grade village gear keeps deaths under 2% to level 14. So
the hunt went out with the starting gear, the inventory and each village's shop, and the trainer
followed (rules §25).

## Death and the Halls

Built (rules §21).

- **Death is final.** At 0 HP the run ends and the character is gone, but not forgotten: the row
  is kept, never deleted, with who killed it and where.
- **The Monument of Heroes,** the highscores rebuilt from the legacy Halls: every run ranked by
  level and then EXP, the living, the fallen and the missing, overall and by lineage, with medals
  for the top three. In Interlude it is the heroes' obelisk that stands in every town.
- **Later, with the Chronicle:** a run's public record page and its "last sighted".

## Skills

- **Every set has a first skill from its own tree:** Power Strike, Power Shot, Mortal Blow and
  Iron Punch for the Human, Elven, Dark and Orc Fighters, the skills of the weapons they start with;
  Wind Strike for the Human, Elven and Dark Mystics and Chill Flame for the Orc, known from the
  start. Nothing else comes free.
- **SP comes from monsters,** like EXP.
- **A short list per set** until the first class change, learned with SP from the trainers of the
  character's own village (rules §25, built): the first skill and two to five more from its canon
  tree, chosen so each set plays its own way (rules §19), and three masteries. The rest are
  actives, a heal, an aura, a drain, a curse or a toggle; the masteries are passives, Armor Mastery
  for a Fighter and Robe Mastery for every Mystic, and Weapon Mastery and Anti Magic for both, and
  the guild shelves the two kinds apart. Whether to learn a mastery is the player's: Anti Magic
  answers only spells, which the village grounds barely cast (the Orc Village's Evil Eyes aside) and
  Gludio's and Dion's will. The auras are the first timed buffs, as the Temple's will be: each holds 2 minutes, raised
  before the pull, and counts down over its icon and on the character page. The character page's
  Skills panel is the spellbook: what it knows, in the numbers the fight uses for it (what a heal
  mends, how often a blow lands, each one's cast and reuse), never a formula.
- **A skill grows in steps** of up to 4 lines, each a character level's worth of canon levels, and
  the trainer shows only each skill's next line, no two lines of one skill opening at one level.
  Every set starts knowing its first skill, and the SP left from level 15 waits for the class
  change's skills.
- **The class change opens the specialised skills** of the new class, learned the same way.
- **Skills matter most in the slower fights,** where a boss is fought in rounds with a choice each
  round.

## Classes

Needs the class tree in the canon first.

- **Fighter and Mystic** are already the two paths of the base layer.
- **Priced against what a run brings to 20:** 13,600 to 19,600 SP (a Mystic 17,200 or more) and 224,000 to 362,000 Adena
  with nothing left to buy in the village ([balance.md](balance.md)).
- **Class transfers** at levels 20 and 40, and a third at 76, where each next class grows HP and MP
  differently.
- **Only in the starting village,** from its master (a departure, listed in the canon): High Priest
  Biotin on Talking Island, Hierarch Asterios in Elven Village, Tetrarch Thifiell in Dark Elf
  Village, Flame Lord Kakai in Orc Village. A first version is in `legacy/`, at the Class Master.
- **The Orcs' perk:** they shrug off sleep, root and poison, which rules §16 names and debuffs
  will give numbers to.
- **Dyes** that trade one attribute for another, at most +5 to each. A first version is in
  `legacy/`, at the Symbol Maker.

## The inventory

Built with the first hunt (rules §23 and §24).

- **Three pieces of armour** (chest, legs, necklace) beside the weapon and shield, each standing for
  its whole part of the body.
- **The sidebar's Inventory panel shows what is equipped and the Adena,** with one link to the
  inventory page beside the purse.
- **The sidebar's Consumables panel, above it, counts every stack carried,** so potions (and shots,
  when they come) are seen without opening the bag. It is not a slot, so with nothing carried there
  is no panel at all, rather than one naming what is missing.
- **The inventory page** holds everything carried, equipped or not, puts it on or takes it off,
  drinks a potion and destroys what isn't wanted. The share of HP a fight drinks below (rules §26)
  is a battle order, under the hunting ground.
- **Every set starts with its kit,** the wearable part equipped: a weapon for each skill path, none
  of it sold in a shop.
- **Each village's trader** sells the canon village lists at canon prices, each armour piece by the
  share of its part it stands for, with no tax, and buys back for half.
- **The bag holds 15 items,** worn ones included and a potion's stack as one, so outgrown gear is
  sold rather than hoarded.
- **Next:** a player shop opened from the inventory page, by choosing what to sell and for how much.

## Items

- Weapons by type, each with its own damage spread (rules §23, built).
- Armour by slot, adding to the body a path starts with (rules §23, built).
- Jewellery adding to the mind (rules §23, built).
- Shields that can block a blow, adding their defence to it (rules §23, built), the chance shown
  beside P. Def.
- Grades (D, C, B, A, S) and a penalty for wearing gear above your level.
- Soulshots and spiritshots for stronger blows and spells, bought only from player shops. They stack
  as a potion does (rules §26): one place in the bag however many, bought by the lot, sold whole,
  counted in the Consumables panel. Only the two, with no blessed spiritshot: 🔶 a soulshot and 🔷 a
  spiritshot, one shape for one mechanism and Lineage II's crystal colours to tell them apart.
- Potions that mend at once (rules §26, built): the Lesser Healing Potion in the villages; better
  potions and potions for MP from the Town of Gludio on, each town's trader its own. A Mana Potion
  is an order of its own beside 🧪 Drink Healing Potion, its share of MP (`mana_potion_at`) rather
  than a second meaning for `potion_at`, and like it shown only while one is carried.

## Player shops

Needs private stores in the canon first.

- **Any character can open a shop in any town,** choosing what to sell and what to buy, and at
  what price.
- **It stays open while its owner is away,** and the character sits in that town, unable to hunt or
  travel, until the shop closes.
- **Other players find it in that town** and trade with it, which gives them a reason to go there.
- **The only source of soulshots and spiritshots** (a departure: in Lineage II grocers sold them).

## Crystals and shots

Discussed in full when it is built.

- **Gear is turned into crystals,** and crystals into soulshots and spiritshots with a recipe.
- **A recipe per grade,** D, C, B, A and S, dropped by bosses and special places, never by the
  village grounds.

## Towns and their services

- **The Temple in every town,** selling buffs at their real names and strengths, as a departure: in
  Lineage II no priest buffed. Gludio sells the basic ones and each later town adds stronger ones.
  The villages don't have it.
- **Shops in each town,** better gear in more advanced towns, for more money. Not every town has
  every shop. The Town of Gludio's brings the 244,000 tier the villages stop short of (Falchion,
  Sword Breaker, Composition Bow, as Lineage II's towns sold them); the Zweihander stays the
  villages' own.
- **The trainers (built, rules §25) and the class master in each village,** for its own race.
- **The Newbie Guide in each village,** with its free buffs at their real level ranges.

## Fighting

The slower fights, for bosses and dungeons.

- Rounds, with speed deciding how many blows and spells each side gets per round, and a choice of
  skill each round.
- The hunt's clock (rules §20): each round 1⅔ seconds of fight time however long the player
  thinks, so a cast and a reuse count in rounds as they do in the hunt.
- Positions drawn at random: front, side or behind.
- Spells that fail more often against higher-level targets.
- Debuffs, resisted by the attribute that guards against them.
- Lethal blows that cut a monster's HP down at once.
- EXP shared by the damage dealt, smaller against much weaker monsters, with a bonus for an
  overkill.

## The world

- More of the mainland past Dion: Giran and Giran Harbor are listed by rules §14, and not open yet.
- A ground by each town, at its own level band, then dungeons.
- Monsters with their own stats, levels, EXP and Adena. Their EXP is on the scale of rules §12,
  where level 2 is 68 EXP and level 80 is 4.2 billion, or the first kill levels a character.
- **Raid and grand bosses,** fought in rounds: Gludio and Dion's raid bosses first, then Queen Ant,
  and in time Antharas.

## Open questions

Each is decided when its system's rule is written, not before.

- **What a class transfer asks.** In Lineage II it was a quest. Here it might be only a level and a
  fee.
- **Whose clock an aura runs on in a long fight.** Its 2 minutes are the world's today, which an
  instant hunt never notices; a boss fight of 72 rounds is 2 minutes of fight time, and a player
  thinking over each round would watch the world's run out first.
