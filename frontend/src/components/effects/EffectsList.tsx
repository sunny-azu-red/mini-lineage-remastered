import type { EffectView } from '@shared/contract';
import { useEffectCountdown } from '@/hooks/useEffectCountdown';
import { useGameStore } from '@/store/gameStore';
import EffectIcon from './EffectIcon';

/**
 * Calls `useEffectCountdown()` exactly ONCE and passes `now` down, so the whole row shares a
 * single interval. Renders exactly what the server sent and never withdraws an effect on its
 * own — `buildPlayerSnapshot` already excludes expired effects from both `effects[]` and `stats`,
 * so deferring to the server keeps the icon and the numbers it drives in sync, atomically.
 */
export default function EffectsList({ effects }: { effects: EffectView[] }) {
    const now = useEffectCountdown();
    const stampedAt = useGameStore(state => state.effectsStampedAt);
    // Floored at zero so `remainingMs - elapsed` can never exceed the effect's real length.
    const elapsed = Math.max(0, now - stampedAt);

    return (
        <>
            {effects.map(effect => <EffectIcon key={effect.id} effect={effect} elapsed={elapsed} />)}
        </>
    );
}
