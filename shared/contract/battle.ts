import type { PlayerSnapshot } from './player';
import type { FlashView, SoundName } from './common';

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

export interface BattleFightResult {
    player: PlayerSnapshot;
    outcome: BattleOutcome;
    narrative: BattleNarrative;
    ambushed: boolean;   // state AFTER this fight (may re-trigger a new ambush)
    died: boolean;
    flash: FlashView | null;   // level-up flash
    sound: SoundName | null;   // one resolved sound; precedence decided server-side (ambush > crit > level)
}
