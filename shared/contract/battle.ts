import type { PlayerSnapshot } from './player';
import type { FlashView, SoundName } from './common';
import type { BattleNarrative, BattleOutcome } from './battle-narrative';

// Re-exported so existing `import type { BattleNarrative } from '@shared/contract/battle'`-style
// importers (and the `@shared/contract` barrel) keep working unchanged — see battle-narrative.ts
// for why the definitions themselves live there instead of here.
export type { BattleNarrative, BattleOutcome } from './battle-narrative';

export interface BattleFightResult {
    player: PlayerSnapshot;
    outcome: BattleOutcome;
    narrative: BattleNarrative;
    ambushed: boolean;   // state AFTER this fight (may re-trigger a new ambush)
    died: boolean;
    flash: FlashView | null;   // level-up flash
    sound: SoundName | null;   // one resolved sound; precedence decided server-side (ambush > crit > level)
}
