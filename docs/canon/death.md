# Death

Part of the Lineage II canon (Interlude, C6): the reference the game takes names and numbers from.
It is not a roadmap. Read [README.md](README.md) before using an entry.

What the client says to a character that has died, and who keeps the dead.

## What the client says

- **Items after death** **(single source)**: system message 1332, `NO_ITEMS_AFTER_DEATH`: "Items may not be used after your character or pet dies." Sources: [github:DEVjEXTREME/L2jaCis-409](https://github.com/DEVjEXTREME/L2jaCis-409/blob/main/aCis_gameserver/java/net/sf/l2j/gameserver/network/SystemMessageId.java).
- **Restart** **(single source)**: a dead character restarts in a village, one message per place: 941 "Restart at Talking Island Village.", 945 "Restart at the Elven Village.", 946 "Restart at the Dark Elf Village.", 951 "Restart at the Orc Village.", and the same for each town. Sources: [github:DEVjEXTREME/L2jaCis-409](https://github.com/DEVjEXTREME/L2jaCis-409/blob/main/aCis_gameserver/java/net/sf/l2j/gameserver/network/SystemMessageId.java).
- **No message says the character died** **(single source)**: neither pack's system messages tells a character it has fallen (only a pet's, 1519); the client shows the Restart choices above and nothing more. Sources: aCis `SystemMessageId.java` (the fork [github:L2GP/aCis-409](https://github.com/L2GP/aCis-409)) and L2jServer Interlude's, two L2J packs.
- **Death Penalty** **(single source)**: 1916 "Your Death Penalty is now level $s1." and 1917 "Your Death Penalty has been lifted." Sources: [github:DEVjEXTREME/L2jaCis-409](https://github.com/DEVjEXTREME/L2jaCis-409/blob/main/aCis_gameserver/java/net/sf/l2j/gameserver/network/SystemMessageId.java).

## Who keeps the dead

- **Shilen** **(single source)**: "the goddess of death", whose power broke Kamaloka off "from the cosmic ether"; Einhasad is "the main god". The Dark Elves follow Shilen ([races.md](races.md)). Sources: [engadget.com](https://www.engadget.com/2008-07-03-lineage-ii-lore-of-upcoming-expansion-gracia-part-1.html).
- **Monument of Heroes**: the Olympiad's obelisk, one in each of 16 towns ([skills.md](skills.md)).

## Disputes and caveats

- The system messages were read from aCis alone; the L2J packs carry the same client file but were not checked. The Gracia article is about a later chronicle's expansion, and is used only for who Shilen is, which Interlude's Dark Elves already name.
