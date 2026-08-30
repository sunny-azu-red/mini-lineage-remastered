import type { EffectView } from '@shared/contract';
import { useEffectCountdown } from '@/hooks/useEffectCountdown';
import EffectIcon from './EffectIcon';

/**
 * Calls `useEffectCountdown()` exactly ONCE and passes `now` down, so the whole row shares a
 * single interval.
 *
 * Effects already past `expiresAt` are filtered out against that same `now`, matching the old
 * render-time `getActiveEffects()` behaviour: a buff vanished the instant it expired rather than
 * freezing at "0" until the next push. Expiry stays server-authoritative for game state; this
 * only ever hides something the server would shortly agree is gone.
 */
export default function EffectsList({ effects }: { effects: EffectView[] }) {
    const now = useEffectCountdown();

    return (
        <>
            {effects
                .filter(e => e.expiresAt === undefined || e.expiresAt > now)
                .map(effect => <EffectIcon key={effect.id} effect={effect} now={now} />)}
        </>
    );
}
