import type { EffectView } from '@shared/contract';
import { useEffectCountdown } from '@/hooks/useEffectCountdown';
import { useGameStore } from '@/store/gameStore';
import EffectIcon from './EffectIcon';

/**
 * Calls `useEffectCountdown()` exactly ONCE and passes `now` down, so the whole row shares a
 * single interval.
 *
 * Renders exactly what the server sent, and never withdraws an effect on its own. It used to hide
 * anything past its `expiresAt` locally, which had nothing to protect against and one real cost:
 * `buildPlayerSnapshot` derives BOTH `effects[]` and `stats` from `getActiveEffects`, so every
 * snapshot already excludes expired effects and every snapshot is internally consistent. Filtering
 * here only ever disagreed with it — early — so the icon vanished while the max HP that same buff
 * was granting stayed put until the next push. Deferring to the server makes the icon and the
 * numbers it drives change in the same snapshot, atomically.
 *
 * `now` still earns its keep: the countdown text is the one thing the client genuinely computes.
 */
export default function EffectsList({ effects }: { effects: EffectView[] }) {
    const now = useEffectCountdown();
    const stampedAt = useGameStore(state => state.effectsStampedAt);
    // One elapsed figure for the whole row, from the one clock reading — so every icon counts down
    // against the same instant. Floored at zero so `remainingMs - elapsed` can never exceed the
    // effect's real length: that is what makes "a 5-second effect cannot display 6" an invariant
    // rather than a consequence of the stamp happening to be written before this render.
    const elapsed = Math.max(0, now - stampedAt);

    return (
        <>
            {effects.map(effect => <EffectIcon key={effect.id} effect={effect} elapsed={elapsed} />)}
        </>
    );
}
