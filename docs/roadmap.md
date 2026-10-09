# Mini-Lineage: the roadmap

What gets built on top of the base rules (`docs/rules.md`), one system at a time. These are ideas
raised so far, not promises. When a system is picked up, its rules are written into `rules.md`
first, and the code follows.

**Old mechanics.** What the game was before the base layer is kept in `legacy/`, to read and never
to run: the Inn, the Weapon and Armor Shops, the Battleground, the Character page and its
Chronicle, the Hall of Champions, the Tome, the Class Master, the Symbol Maker, timed buffs, the
Konami cheat, and every sound but the new-game fanfare and the sound switch's chime. Each is
rebuilt here as its system below, on the base layer, and nothing from `legacy/` comes back as it
was.

## Before the first system

What the base layer already says but nothing exercises yet, because nothing can happen to a
character: each lands with the first system that needs it, almost certainly fighting.

- **Gaining EXP and levelling** (rules §12): reaching a level refills HP and MP, and the player is
  told. Nothing grants EXP yet.
- **Being in combat** (rules §11): resting stops. Today a character always rests.
- **The base outcomes** (rules §13): hit chance and damage are written and tested, and called by
  nothing.
- **What 0 HP means:** death, and what it costs, is not a rule yet.

## Classes

- **Fighter and Mystic** are already the two paths of the base layer.
- **Class transfers** at levels 20 and 40, where each next class grows HP and MP differently. A
  first version is in `legacy/`, at the Class Master.
- A third transfer at level 76.
- **Skills,** which give MP a use.
- **Race perks:**
  - Elves rest faster in their home village
  - Orcs shrug off sleep, root and poison
- **Dyes** that trade one attribute for another, at most +5 to each. A first version is in
  `legacy/`, at the Symbol Maker.

## Items

- Weapons by type, each with its own damage spread.
- Armour by slot, adding to the body a path starts with.
- Jewellery adding to the mind.
- Shields that can block a blow, adding their defence to it.
- Grades (D, C, B, A, S) and a penalty for wearing gear above your level.
- Soulshots and spiritshots as an Adena cost per fight, for stronger blows and spells.
- Potions that heal over time.

## Fighting

- Rounds, with speed deciding how many blows and spells each side gets per round.
- Positions drawn at random: front, side or behind.
- Spells that fail more often against higher-level targets.
- Debuffs, resisted by the attribute that guards against them.
- Lethal blows that cut a monster's HP down at once.
- EXP shared by the damage dealt, smaller against much weaker monsters, with a bonus for an
  overkill.
- Aggressive monsters that attack first.

## The world

- More of the mainland past Dion: Giran and Giran Harbor are listed by rules §14, and not open yet.
- Farming zones, questing zones and dungeons.
- Shops in each town, selling what that town sells.
- Hunting grounds around each race's starting village (rules §1), which is where a character
  stands today with nothing yet to do.
- Monsters with their own stats, levels, EXP and Adena. Their EXP is on the scale of rules §12,
  where level 2 is 68 EXP and level 80 is 4.2 billion, or the first kill levels a character.
- Raid bosses.
