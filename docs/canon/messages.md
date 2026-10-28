# Messages

Part of the Lineage II canon (Interlude, C6): the reference the game takes names and numbers from.
It is not a roadmap. Read [README.md](README.md) before using an entry.

What the client says when a character trades, learns, equips, uses or destroys something, or is
refused, and what the game says in its place. The fight's messages are in [skills.md](skills.md),
death's in [death.md](death.md).

## What the client says

- **Too little Adena**: id 279 "You do not have enough adena.", sent when a shop's total or a
  Gatekeeper's fee is more than the purse. Neither names the item or the fee. Sources: L2J
  `RequestBuyItem` and `PlayerInstance.reduceAdena` (which a teleporter calls), aCis
  `RequestBuyItem` and `Player.reduceAdena` (`YOU_NOT_ENOUGH_ADENA`).
- **A full inventory**: id 129 "Your inventory is full.", sent by a shop before the purse is
  checked. Sources: L2J and aCis `RequestBuyItem` (`YOUR_INVENTORY_IS_FULL`, `SLOTS_FULL`).
- **Too little SP**: id 278 "You do not have enough SP to learn this skill." Sources: L2J
  `RequestAquireSkill`, aCis `RequestAcquireSkill` (`NOT_ENOUGH_SP_TO_LEARN_SKILL`).
- **A lesson out of reach is never refused aloud**: the trainer lists only what can be learned
  now, and a request for any other line (too early, or before the level under it) is dropped
  without a word. aCis returns silently; L2J kicks the client as a cheat. Sources: as above.
- **A trade says nothing on success**: a buy takes the Adena and a sale pays it with their
  messages switched off (`reduceAdena(…, false)`, `addAdena(…, false)`), and the item arrives with
  no message; only the inventory moves. Sources: L2J `RequestBuyItem`, `RequestSellItem`; aCis the
  same.
- **A lesson learned**: id 277 "You have earned $s1." with the skill's name. L2J sends id 538
  "Your SP has decreased by $s1." before it; aCis lowers the SP silently. Sources: L2J
  `RequestAquireSkill` (`YOU_HAVE_EARNED_S1_2`), aCis `RequestAcquireSkill` (`LEARNED_SKILL_S1`).
- **Equipped**: id 49 "You have equipped your $s1." Sources: L2J `UseItem`, aCis `Player`
  (`S1_EQUIPPED`).
- **Unequipped**: id 417 "$s1 has been disarmed.", for armour as for a weapon (an enchanted piece
  takes 1064 "The equipment, +$s1 $s2, has been removed."). Sources: L2J `UseItem`, aCis `Player`
  (`S1_DISARMED`).
- **Destroyed** **(single source)**: id 302 "$s1 has disappeared." (301 "$s2 $s1 has disappeared."
  for a count). aCis's `RequestDestroyItem` destroys with its message on; L2J's sends none. Sources:
  aCis `RequestDestroyItem`, `Player.destroyItem`.
- **A potion says nothing**: it casts its skill, whose heal over time clamps HP and sends no
  message, and neither pack refuses one drunk at full HP. Sources: L2J `Potions`, aCis
  `ItemSkills`; [skills.md](skills.md) has the heal messages, 1066 and 1067.
- **A dead character's item** is refused with 113 "$s1 cannot be used due to unsuitable terms." in
  L2J's `UseItem`, and 1332 "Items may not be used after your character or pet dies." exists
  ([death.md](death.md)).

## What the game says

What each message reads in the game, held to `MiniLineage.Game.Actions` by `messages_test.exs`.
An id is the client's message the line takes; "ours" is the game's own, where the client has
none. A refusal no click can reach (a dropdown offers only what can be done) keeps a code of its
own for the tests and says `invalid`.

| Key | Id | Says |
|---|---|---|
| `invalid` | ours | That is not something you can do. |
| `already_started` | ours | You already have a character. |
| `last_level` | ours | There is no level past the last. |
| `full` | 129 | Your inventory is full. |
| `cannot_afford` | 279 | You do not have enough Adena. |
| `poor` | 279 | You do not have enough Adena. |
| `no_sp` | 278 | You do not have enough SP to learn this skill. |
| `whole` | ours | You are already at full health. |
| `fallen` | ours | Your road has ended, and a ghost changes nothing. |
| `learn` | 277 | You have earned $s1 for $sp. |
| `equip` | 49 | You have equipped your $s1. |
| `unequip` | 417 | $s1 has been disarmed. |
| `destroy` | 302 | $s1 has disappeared. |
| `buy` | ours | You buy $s1 for $adena. |
| `sell` | ours | You sell $s1 for $adena. |
| `drink` | ours | You drink a $s1 and mend $hp. |

`$s1` is the item or skill as `Names` writes it, `$adena` and `$sp` an amount as `Format.adena/1`
and `Format.sp/1` write it, and `$hp` the HP mended in `.regen`. A lesson's line joins its cost,
the client's second message, into one sentence (README, How it is written).

## Disputes and caveats

- L2J and aCis share one client file, so each text above is one source however many packs carry
  it; which message an action sends was read in both packs' handlers.
- The destroy message is aCis's alone: L2J's `RequestDestroyItem` destroys silently.
