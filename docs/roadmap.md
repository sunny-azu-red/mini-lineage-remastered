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
to run: the Inn, the Weapon and Armor Shops, the Battleground, the Character page and its
Chronicle, the Hall of Champions, the Tome, the Class Master, the Symbol Maker, timed buffs, the
Konami cheat, and every sound but the new-game fanfare and the sound switch's chime. Each is
rebuilt here as its system below, on the base layer, and nothing from `legacy/` comes back as it
was.

**Where the content goes.** A system's tables (monsters, items, skills) start in `Rules` beside the
base layer's, held to this document by `rules_test.exs`. When one grows into the hundreds it moves
to a data file under `priv/` loaded at compile time, still in git; it goes into Postgres only if it
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

The first thing to build, with the canon's monster stats researched first.

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
  with blows at Atk. Spd., spells at Casting Spd. and the set's first skill. It pays EXP, SP and
  Adena.
- **It can kill.** There is no warning; the HP bar is the player's to read.
- **Then Gludio:** Ruins of Despair, levels 15 to 24.

## Built with the first hunt

The hunt (rules §17 to §21) put the base layer to work: EXP and levelling (§12) with the level-up
told, the base outcomes (§13), SP, death and the Monument of Heroes. Being in combat (§11) waits for
the slower fights, since a one-click hunt takes no time.

**It ships with the inventory and the village shops.** A seeded run of the first hunt showed that a
character without gear dies in most fights by level 10, because Lineage II's monsters assume a
weapon and armour, while the canon's no-grade village gear keeps deaths under 2% to level 14. So
the hunt goes out with the starting gear, the inventory and each village's shop, and the trainer
follows before characters reach 15.

## Death and the Halls

- **Death is final.** At 0 HP the run ends and the character is gone, but not forgotten: the row
  is kept, never deleted, with who killed it and where.
- **The Monument of Heroes,** the highscores rebuilt from the legacy Halls: every run ranked by
  level and then EXP, the living, the fallen and the missing, overall and by lineage, with medals
  for the top three. In Interlude it is the heroes' obelisk that stands in every town.
- **Later, with the Chronicle:** a run's public record page and its "last sighted".

## Skills

- **Every set starts with one skill from its own tree, and each race's differs:** Power Strike,
  Power Shot, Mortal Blow and Iron Punch for the Human, Elven, Dark and Orc Fighters; Wind Strike,
  Ice Bolt, Vampiric Touch and Chill Flame for the Human, Elven, Dark and Orc Mystics.
- **SP comes from monsters,** like EXP.
- **A short list per set** until the first class change, different for each race, learned with SP
  from the trainers of the character's own village. The list is the character's spellbook: what it
  knows, and what it can learn next.
- **The class change opens the specialised skills** of the new class, learned the same way.
- **Skills matter most in the slower fights,** where a boss is fought in rounds with a choice each
  round.

## Classes

Needs the class tree in the canon first.

- **Fighter and Mystic** are already the two paths of the base layer.
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

Needs the paperdoll and inventory limits in the canon first.

- **The sidebar panel shows what is worn and the Adena,** with an "Open inventory" link.
- **The inventory page** holds everything a character carries, equipped or not, kept until it is
  used, sold or dropped. Items are equipped and taken off from here. How many of the real slots a
  mini game keeps is decided when the rule is written.
- **Every set starts with its canon gear,** equipped (canon `races.md`).
- **A player shop is opened from the inventory page,** by choosing what to sell and for how much.
- **It is its own table,** since it grows with play.

## Items

- Weapons by type, each with its own damage spread.
- Armour by slot, adding to the body a path starts with.
- Jewellery adding to the mind.
- Shields that can block a blow, adding their defence to it.
- Grades (D, C, B, A, S) and a penalty for wearing gear above your level.
- Soulshots and spiritshots for stronger blows and spells, bought only from player shops.
- Potions that heal over time.

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
  every shop.
- **The trainers and the class master in each village,** for its own race.
- **The Newbie Guide in each village,** with its free buffs at their real level ranges.

## Fighting

The slower fights, for bosses and dungeons.

- Rounds, with speed deciding how many blows and spells each side gets per round, and a choice of
  skill each round.
- Positions drawn at random: front, side or behind.
- Spells that fail more often against higher-level targets.
- Debuffs, resisted by the attribute that guards against them.
- Lethal blows that cut a monster's HP down at once.
- EXP shared by the damage dealt, smaller against much weaker monsters, with a bonus for an
  overkill.
- Aggressive monsters that attack first.

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
