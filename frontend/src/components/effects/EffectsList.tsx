import type { EffectView } from '@shared/contract';
import { useEffectCountdown } from '@/hooks/useEffectCountdown';
import EffectIcon from './EffectIcon';

/**
 * Calls `useEffectCountdown()` exactly ONCE and passes `now` down, so the whole row shares a
 * single interval.
 *
 * Buffs and debuffs already past `expiresAt` are filtered out against that same `now`, matching
 * the old render-time `getActiveEffects()` behaviour: one vanished the instant it expired rather
 * than freezing at "0" until the next push. Expiry stays server-authoritative for game state;
 * this only ever hides something the server would shortly agree is gone.
 *
 * Auras are exempt, because that premise does not hold for them: a zone aura is REPLACED, not
 * removed (⚔️ In Combat's disengage countdown becomes 💤 Resting). Hiding it early would leave a
 * hole in the row for the ~30ms until the push lands, showing a state the game never has.
 */
export default function EffectsList({ effects }: { effects: EffectView[] }) {
    const now = useEffectCountdown();

    return (
        <>
            {effects
                .filter(e => e.type === 'aura' || e.expiresAt === undefined || e.expiresAt > now)
                .map(effect => <EffectIcon key={effect.id} effect={effect} now={now} />)}
        </>
    );
}
