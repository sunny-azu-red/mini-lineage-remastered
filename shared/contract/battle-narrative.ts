import type { SoundName } from './common';

// Split out from battle.ts (which re-exports both) to avoid an import cycle with player.ts.
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

/** Reconnect-safe half of BattleFightResult — everything but `player`/`flash`, always fresh. */
export interface BattleNarrativeSnapshot {
    narrative: BattleNarrative;
    outcome: BattleOutcome;
    ambushed: boolean;  // state AFTER the fight — display only; PlayerSnapshot.ambushed is live truth
    died: boolean;
    sound: SoundName | null;
}
