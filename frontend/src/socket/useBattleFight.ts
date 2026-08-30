import { useAction } from './useAction';
import { useGameStore } from '@/store/gameStore';
import { playSound } from '@/audio/soundfx';

/**
 * The single place `battle:fight` is ever fired from — BattleScreen's Fight button and
 * HomeScreen's "travel to Battlefield" both call this.
 *
 * Deliberately does NOT navigate on death: BattleScreen handles that transition via its own
 * effect, so this hook stays usable from any screen.
 */
export function useBattleFight(): { pending: boolean; fight: () => void } {
    const { run, pending } = useAction('battle:fight');
    const recordBattleResult = useGameStore(state => state.recordBattleResult);

    const fight = () => void run({}, {
        onSuccess: data => {
            recordBattleResult(data);
            playSound(data.sound);
        },
    });

    return { fight, pending };
}
