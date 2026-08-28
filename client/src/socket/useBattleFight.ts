import type { BattleFightResult } from '@shared/contract';
import { useAction } from './useAction';
import { useGameStore } from '@/store/gameStore';
import { playSound } from '@/audio/soundfx';

interface UseBattleFightResult {
    pending: boolean;
    /** Fires the ONE shared `battle:fight` action used by both BattleScreen and AmbushBanner. */
    fight: () => void;
}

/**
 * The single place `battle:fight` is ever fired from. BattleScreen's own "⚡"/"⚔️" button and
 * AmbushBanner's "⚔️ Fight!" button both call this — same event, same payload, same success
 * handling — so clicking Fight from the banner (while browsing some other screen mid-ambush) is
 * indistinguishable in code path from clicking it on the Battle screen itself.
 *
 * Deliberately does NOT navigate on `died: true` — BattleScreen reacts to that via its own
 * `useEffect` on `lastBattle`/`player.dead` (see BattleScreen.tsx), so this hook stays usable
 * from any screen (AmbushBanner navigates to 'battle' itself before calling `fight()`) without
 * fighting over who's responsible for the death transition.
 */
export function useBattleFight(): UseBattleFightResult {
    const { run, pending } = useAction('battle:fight');
    const recordBattleResult = useGameStore(state => state.recordBattleResult);

    function fight(): void {
        void run(
            {},
            {
                onSuccess: (data: BattleFightResult) => {
                    recordBattleResult(data);
                    playSound(data.sound);
                },
            },
        );
    }

    return { fight, pending };
}
