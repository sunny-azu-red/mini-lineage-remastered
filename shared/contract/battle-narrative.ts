import type { SoundName } from './common';

/**
 * `BattleNarrative`/`BattleOutcome` live here — not in `battle.ts` alongside `BattleFightResult`
 * — specifically so `player.ts` can import them (for `PlayerSnapshot.lastBattle`, see
 * `BattleNarrativeSnapshot` below) without creating a cycle: `battle.ts` itself imports
 * `PlayerSnapshot` from `./player`, so `player.ts` importing anything back out of `battle.ts`
 * would close a loop. `battle.ts` re-exports both for existing importers, so nothing outside
 * this file needs to know the split happened.
 */
export interface BattleNarrative {
    critLine: string | null;
    killLine: string;
    deflectionLine: string;
    outcomeLine: string;
    ambushLine: string | null;   // set iff ambushed === true (after this fight)
    fightPrompt: string | null;  // "Face your Foe!" / "Fight them!" — set iff ambushed
    nextMove: string;            // random BATTLE_MOVES label for the "continue" button
}

export interface BattleOutcome {
    enemiesKilled: number;
    hpLost: number;
    damageBlocked: number;
    xpGained: number;
    adenaGained: number;
    isCritical: boolean;
    isLevelUp: boolean;
}

/**
 * The persisted, reconnect-safe shape of a resolved fight's narrative — everything
 * `BattleFightResult` carries EXCEPT `player`/`flash`, which are always freshly derived from the
 * live `PlayerState`/mutation result, never stale. Mirrors the exact pattern already proven for
 * `deathReason` (see `src/service/player.service.ts`'s `resolveDeathReason`): resolve once,
 * persist on `PlayerState` (as `lastBattleNarrative`), carry it in every `buildPlayerSnapshot()`
 * call (as `PlayerSnapshot.lastBattle`) so it survives any reconnect — a real page reload no
 * longer wipes it back to a generic placeholder.
 */
export interface BattleNarrativeSnapshot {
    narrative: BattleNarrative;
    outcome: BattleOutcome;
    ambushed: boolean;  // state AFTER the fight resolved — display-only, see PlayerSnapshot.ambushed for live truth
    died: boolean;
    sound: SoundName | null;
}
