import type { SoundName } from './common';

/**
 * Lives here rather than in `battle.ts` so `player.ts` can import it without a cycle
 * (`battle.ts` imports `PlayerSnapshot` from `player.ts`). `battle.ts` re-exports both.
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
 * The persisted, reconnect-safe half of a resolved fight — everything `BattleFightResult`
 * carries EXCEPT `player`/`flash`, which are always derived fresh and never stale. Resolved
 * once and stored on `PlayerState`, the same pattern as `deathReason`, so a page reload
 * replays the real narrative instead of a placeholder.
 */
export interface BattleNarrativeSnapshot {
    narrative: BattleNarrative;
    outcome: BattleOutcome;
    ambushed: boolean;  // state AFTER the fight — display only; PlayerSnapshot.ambushed is live truth
    died: boolean;
    sound: SoundName | null;
}
