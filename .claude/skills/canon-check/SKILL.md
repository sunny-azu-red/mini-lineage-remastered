---
name: canon-check
description: Check a feature against the Lineage II canon in docs/canon before it is built, research what is missing from Interlude's server code, and write each deliberate departure down first. Use before writing a new system, rule, skill, monster, item, mechanic, message or any player-facing name or number, and whenever asked what is canon, what Lineage II did, or whether something fits the Lineage II universe.
---

# The canon check

`docs/canon/README.md` holds the rule: no player-facing Lineage II name or number enters the game
unless the canon has it. This is how a feature is held to it before a line is written, so the game
departs from Lineage II only where somebody decided it should. Report what you find before you
build; the owner decides every departure that is a judgment call.

## 1. What the feature shows

List everything it puts in front of a player: names (a skill, a monster, an item, an NPC, a
place), numbers (a stat, a price, a rate, a reuse), messages (what the client would say), and
mechanics (what happens, in what order, what is capped or rounded). A word the log or a flash
prints counts as much as a number.

## 2. What the canon already says

Read `docs/canon/README.md` whole: the rule, how far to trust an entry (no mark, single source,
uncertain), Not researched yet, and Deliberate departures. Then grep the canon files for each item
from step 1. An entry marked uncertain is checked again before anything depends on it. A topic
under Not researched yet is researched before the system that needs it reaches `docs/rules.md`.

## 3. Research what is missing

Never guess, approximate or invent a plausible value. Find it, then write it into the canon file
that fits (the README's table says which), in that file's form: the fact, its trust mark, and its
sources.

- **The chronicle is Interlude.** A later chronicle's value is not canon, even when it is easier
  to find.
- **Two sources where the topic allows**, at least one outside the L2J family; two L2J packs
  together count as less than two. The README lists the datapacks and item databases.
- **Behaviour is read in the server code, not only the data files**: what a message carries, the
  order of a cap and a message, what a formula clamps. A data file says what a skill is; the
  handler says what the player saw.
- **Start from the local copies** under `tmp/canon_downloads/` (gitignored, partial), then GitHub.
  aCis's `DEVjEXTREME/L2jaCis-409` no longer answers; the fork `L2GP/aCis-409` stands in, and an
  entry read from it says so.

## 4. Compare the plan with the canon

For each item, one of three:

- **Taken whole.** The name, spelling and number as the entry has them, quirks included, never
  rescaled beside numbers that were not.
- **Brought back to canon.** The plan drifted for no reason; change the plan.
- **A deliberate departure.** It differs on purpose: a balance reading (`docs/balance.md`), a text
  game's limits, a rule of our own. It goes into the README's Deliberate departures, in that
  section's voice and under its heading (The world, Characters, Skills…), with what Lineage II did
  and why we differ, *before* it is built. Ask the owner when the reason is taste rather than a
  measurement or a constraint.

A system the canon has no word for at all (a fight log, a sidebar) is ours, but any Lineage II name
or number inside it still passes through steps 2 to 4.

## 5. Report

Before building, tell the owner in a few lines: what Lineage II did (with the entry or source),
what the feature takes whole, what departs and why, and what was researched into the canon. Then
build, with `docs/rules.md` and `Rules` taking the canon's numbers whole as AGENTS.md says.
