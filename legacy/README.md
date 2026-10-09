# legacy/

The game as it was at commit `da4e37c`, before it was cut back to the base layer of
`docs/rules.md`. It is kept to be **read**, never run: nothing here is compiled, formatted, tested
or served, and nothing outside this directory may depend on it.

What is in it, and where a system that replaces one of them should start reading:

| Was | Look in |
|---|---|
| The Inn, the Weapon and Armor Shops | `lib/mini_lineage_web/screens/shop.ex`, `lib/mini_lineage/game/player.ex` (`purchase`) |
| The Battleground, ambush, death | `lib/mini_lineage/game/battle.ex`, `actions.ex`, `narratives.ex` |
| The Character page and its Chronicle | `lib/mini_lineage_web/screens/record.ex`, `lib/mini_lineage/character_log.ex`, `assets/js/hooks/log.js` |
| The Hall of Champions | `lib/mini_lineage/board.ex`, `lib/mini_lineage_web/screens/halls.ex` |
| The Tome of statistics | `lib/mini_lineage/game/statistics*`, `lib/mini_lineage_web/screens/tome.ex` |
| Class transfers, dyes | `lib/mini_lineage/game/classes.ex`, `dyes.ex`, `priv/data/dyes.json` |
| Timed buffs, food, the Newbie Blessing | `lib/mini_lineage/game/player.ex` (`effects`), `assets/js/hooks/effect-timers.js` |
| Sounds, the Konami cheat, stamps, sortable tables | `assets/js/` (the new-game fanfare and the toggle's chime are live again) |
| The rules that governed all of it | `AGENTS.md` |

Its `AGENTS.md` describes the code here, not the live game; the live rules are the root
`AGENTS.md` and `docs/rules.md`. Its CSS was pruned from the live stylesheet, so a page lifted from
here needs its rules lifted too, from `assets/css/`.
