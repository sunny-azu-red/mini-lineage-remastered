import type { BattleFightResult } from '@shared/contract';
import { useAction } from './useAction';
import { useGameStore } from '@/store/gameStore';
import { playSound } from '@/audio/soundfx';

interface UseBattleFightResult {
    pending: boolean;
    /** Fires the ONE shared `battle:fight` action, called independently by both BattleScreen and HomeScreen. */
    fight: () => void;
}

/**
 * The single place `battle:fight` is ever fired from. BattleScreen's own "⚡"/"⚔️" button and
 * HomeScreen's "travel to Battlefield" destination both call this via their own independent
 * `useBattleFight()` — same event, same payload, same success handling.
 *
 * Deliberately does NOT navigate on `died: true` — BattleScreen reacts to that via its own
 * `useEffect` on `lastBattle`/`player.dead` (see BattleScreen.tsx), so this hook stays usable
 * from any screen without fighting over who's responsible for the death transition.
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
