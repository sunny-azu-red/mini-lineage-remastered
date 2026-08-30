import type { PlayerSnapshot } from './player';
import type { FlashView, SoundName } from './common';
import type { BattleNarrative, BattleOutcome } from './battle-narrative';

// Re-exported so importers (and the barrel) need not know the definitions live next door.
export type { BattleNarrative, BattleOutcome } from './battle-narrative';

export interface BattleFightResult {
    player: PlayerSnapshot;
    outcome: BattleOutcome;
    narrative: BattleNarrative;
    ambushed: boolean;         // state AFTER this fight (may re-trigger a new ambush)
    died: boolean;
    flash: FlashView | null;   // level-up flash
    sound: SoundName | null;   // precedence resolved server-side: death > level > ambush > crit
}
