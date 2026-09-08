# parity.json

Frame-by-frame output captured from the **TypeScript reference implementation**, replayed by
`test/mini_lineage/game/parity_test.exs`.

The balance golden master pins nine integers at the end of 400 fights. This pins everything it
does not reach: the exact narrative and flash strings, every purchase message, the full stat
pipeline, the XP curve, effect tooltips, and the derived numbers in a player snapshot. A
formatting change that never moves a golden integer still fails here.

Sixteen scenarios: four races × three seeds played normally, plus one deliberately wealthy run per
race. The wealthy runs exist because the ordinary simulation never gets past weapon tier 1 — they
buy the top tier at once and then walk back down as the purse drains, which is the only path any
test takes through the innate crit and regen modifiers on the last three weapons and armors.

## Regenerating

The generator ran inside the reference implementation and is deleted along with it at cutover. It
was a Vitest file under `test/backend/service/` that mocked the statistics repository, drove the
same LCG the golden master uses, and dumped one frame per action. Recovering it means recovering
the reference implementation from git history.

**This fixture is therefore frozen.** A deliberate change to game text or formatting means editing
the expectations here in the same commit — exactly like the golden values.
