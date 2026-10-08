# Mini-Lineage: a faithful mini Lineage II

## Context

The base systems are strong: effects, regen, the Chronicle, live records, the Halls and PubSub. The content is thin, and much of it was invented to look plausible. A verified audit (every name checked against Interlude datapacks and at least two sources) found these invented or misspelled:

- Elven Needle, Calamity Comet, Echos of Valhalla, "The" Forgotten Blade
- Peasant's Tunic, Knight's Plate, Royal Chainmail, Eternal Aegis
- all five foods and all three food buffs; Lineage II has no food
- Newbie Blessing, Hexed
- "City of Aden", the Inn

The race numbers are also backwards: Orcs have the highest CON yet regen 0 here, and Dark Elves the lowest CON yet more HP than Elves.

Levels add nothing (`Player.stats_from/2`, `player.ex:212`), and danger scales from your own weapon (`math.ex:80`).

**What you decided:**
- This is **mini** Lineage II: simplified versions of the real systems, faithful in **names and numbers**, never invented. Interlude is the reference.
- **A new, stronger stat base:** STR, CON, DEX, INT, MEN and WIT give P.Atk, M.Atk, P.Def, M.Def, Max HP, Max MP and Critical, through simplified real formulas. An **MP bar sits under HP** with its own regen.
- **Real numbers:** item stats, prices, teleport fees, race templates.
- **Each race starts in its own village.** Towns are safe, and events only happen on the road out. The Gatekeeper charges real fees. Not every town has every shop.
- **Kept as deliberate departures:**
  - the Temple **buff seller**, selling real buffs: Might, Shield, Focus, Blessed Body, Regeneration
  - the leaderboards, the Tome, the Chronicle, the 👻 Ghost aura, Resting / In Combat, the cheat
- **Renamed where Lineage II has a match:** the Hall of Champions becomes the **Monument of Heroes**. **Commit Suicide is removed.**
- No classes or skill trees, no bag. Light bounties are a counter in a sidebar panel.

**Sources:**
- Verified data: the canon workflow's journal, `~/.claude/projects/-home-seth-mini-lineage-remastered/058168f7-ec31-4d6a-af37-aa5fe63e9104/subagents/workflows/wf_86c33609-02b/journal.jsonl`.
- Formulas: L2J Mobius CT_0 Interlude, `mechanics/stats/Formulas.java`, `functions/formulas/*.java` and `data/stats/statBonus.xml`.
- `lineage2.network/formulas/` sits behind a Cloudflare challenge. If you want that site's version, paste the page and it gets checked against these.

## Phase 1: the new base. This is what approval starts.

0. **Canon reference in the repo.** `docs/lineage2-canon.md` holds the verified names, numbers and source URLs used below, so every later change cites it instead of guessing. AGENTS.md gets the rule: *no player-facing L2 name or number that is not in the canon file*.
1. **Balance harness first.** A seeded run with a competent policy. It reports fights per tier, deaths per 100 runs, and HP and MP spent per fight. It is a script under `bench/` (or a test excluded by default) using `Rng.put_source/1` and `Test.Lcg`. It runs before and after every number below changes.
2. **Six base stats per race,** from the real Fighter templates:
   - Human 40/43/30/21/11/25 (STR/CON/DEX/INT/WIT/MEN)
   - Elf 36/36/35/23/14/26
   - Dark Elf 41/32/34/25/12/26
   - Orc 40/47/26/18/12/27

   They live in `@races` in `constants.ex`, replacing `start_health`, `regen` and `crit`. **Ambush chance stays ours**, because Lineage II has no ambush.
3. **Derived stats, simplified real formulas,** in `Math`/`Player.stats_from/2`. Bonus curves use the closed forms in `statBonus.xml` (STR `1.036^(STR−34.845)`, CON `1.030^(CON−27.632)`, DEX `1.009^(DEX−19.360)`, INT `1.020^(INT−31.375)`, MEN `1.010^(MEN+0.060)`), and the level mod is `(level+89)/100`.
   - P.Atk = weapon × STR × level mod
   - M.Atk = weapon × level mod² × INT²
   - P.Def = armour × level mod
   - M.Def = jewellery × MEN × level mod
   - Max HP = class HP(level) × CON
   - Max MP = class MP(level) × MEN
   - Critical = base × DEX × 10
   - HP regen from CON, MP regen from MEN

   **Levels now add HP and MP and scale every stat.** WIT is shown but feeds nothing until Mystic exists. AGENTS.md says why.
4. **The fight, faithful and still one click.** A fight is one monster with real stats (HP, P.Atk, M.Atk, P.Def, M.Def, EXP, Adena), resolved as an exchange:
   - you hit for `76 × P.Atk ÷ P.Def`, crits ×2, with Critical as the chance
   - it hits for the same physical formula, plus `91 × √M.Atk ÷ M.Def` from casters
   - the rounds to kill it decide what you lose
   - the rewards are its real EXP and Adena

   This is a new `Battle` module, so danger comes from the monster and gear answers it. The golden master is rewritten deliberately, in its own commit.
5. **One village to prove it: Talking Island Village,** with its real grounds and monsters from the canon (Obelisk of Victory, Singing Waterfall, Elven Ruins…). It replaces the Battleground, and each ground has a URL: `/hunt/:ground`.
   - Ambushes hold you in their ground through a new `pin_screen` clause, not a widened one.
   - Stored runs load onto Talking Island's first ground.
   - All four races start here only until Phase 2, and Phases 1 and 2 ship together.
6. **Renames to canon** (names, numbers and real prices; `@weapons`/`@armors` stay append-only by index):
   - **Weapons:** Squire's Sword (Training Gloves for Orcs, the real starting gear), Elven Sword, Stormbringer, Sword of Valhalla, Dark Legion's Edge, Forgotten Blade.
   - **Armour:** Squire's Shirt, Brigandine Tunic, Full Plate Armor, Blue Wolf Breastplate, Majestic Plate Armor, Imperial Crusader Breastplate.
   - The **Inn becomes the Grocer,** selling Lesser Healing, Healing, Greater Healing and Quick Healing Potion. The real ones heal over time, which becomes a short regen effect. The Max HP food buffs go.
   - **Newbie Blessing** becomes the real Newbie Guide buffs ("Shield for Beginners"… at their real level ranges). **Hexed** becomes **Hex** (P.Def ×0.77).
   - Narratives: "Critical hit!" stays; invented exclamations and place names go; prose names the gods (Einhasad, Shilen, Paagrio, Gran Kain…) where it names gods.
   - Stat labels follow the client: P. Atk., P. Def., Critical.
7. **The Monument of Heroes** replaces the Hall of Champions in titles and prose. Routes are unchanged.
8. **Commit Suicide is removed:** its route, screen, action, `coward` flag, statistic, Tome line and tests. Existing coward rows stay excluded from the board, so history doesn't change.
9. **The MP bar** is drawn under HP with `Controls.bar/1` and regenerated by the existing tick. The "what the player can see is what heals them" rule now covers MP too.
10. **AGENTS.md** gets the new stats, the fight, grounds, the canon rule and the suicide removal written in, in the same change.

## The phases after

- **Phase 2: Home villages.** Elven Village, Dark Elf Village and Orc Village with their real grounds. The Newbie Guide in each, the Gatekeeper at real fees to Gludin and Gludio, and **road events** on the way to a ground, never inside a town. Shops are data with a `town` key, and not every town has every shop. The **Temple buff seller** (a deliberate departure) sells real buffs at real strengths: Might +15% P.Atk, Shield, Focus, Blessed Body, Regeneration, for 20 minutes.
- **Phase 3: Mystic.** At creation, choose your race's Fighter or Mystic: real Mystic templates, staves and robes, fights spending MP through M.Atk. The **Jeweller** sells real necklaces, earrings and rings giving M.Def, against monsters that cast.
- **Phase 4: Dion, bounties, enchanting, shots.** A bounty board with a sidebar panel. Real enchant scrolls by grade: safe to +3 (+4 for full-body armour), failure crystallizes, Blessed resets to 0. Soulshots ×2 P.Atk at real prices per grade.
- **Phase 5: Raid bosses** in rounds, with a few choices: Zombie Lord Crowl, Soul Scavenger, Guilotine, then Queen Ant (Ant Nest, level 40). **Epic jewels** at their real stats: Ring of Queen Ant, Ring of Core, Earring of Orfen. The Monument of Heroes ranks bosses slain (a stored generated column).
- **Phase 6: Giran and beyond:** Dragon Valley, Antharas' Lair, then Aden and Baium.

## Critical files (Phase 1)
`lib/mini_lineage/game/constants.ex`, `math.ex`, `battle.ex`, `player.ex`, `actions.ex`, `access.ex`, `narrative.ex`, `narratives.ex`, `snapshot.ex`, `statistics.ex`; `lib/mini_lineage/characters/serde.ex`, `server.ex`; `lib/mini_lineage_web/router.ex`, `paths.ex`, `screens.ex`, `screens/{shop,halls,tome,record}.ex`, `components/{controls,layouts}.ex`; `assets/js/hooks/animated-values.js` (the MP bar); `test/**/balance_golden_test.exs`, `fight_properties_test.exs`, `format_test.exs`; `e2e/*.mjs`; `AGENTS.md`; `docs/lineage2-canon.md`.

## Verification
- Every new test is seen failing first: the stat formulas against hand-computed L2J values for each race at levels 1, 20 and 80; the fight exchange; the ground pin and what it still refuses; MP regen tied to its aura; legacy runs loading onto Talking Island; the suicide route returning 404.
- A canon test checks that every player-facing item, place, monster and effect name in `Constants` appears in `docs/lineage2-canon.md`.
- `balance_golden_test.exs` is re-pinned only in its own commit. The harness report goes before and after, cited by script name.
- `mix precommit`; `mix e2e`, with the walkthrough on Talking Island (hunt, Grocer, the MP bar). Dice are pinned or `health: 5_000`, and nothing is asserted on a roll. `e2e/release.sh` runs, since a migration may drop `coward`.
- In the running app (Tidewave, reads only): `:sys.get_state` on a character after a ground fight, then look at the pages.
