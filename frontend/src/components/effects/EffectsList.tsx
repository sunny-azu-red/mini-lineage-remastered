import type { EffectView } from '@shared/contract';
import { useEffectCountdown } from '@/hooks/useEffectCountdown';
import EffectIcon from './EffectIcon';

interface EffectsListProps {
    effects: EffectView[];
}

// Calls useEffectCountdown() exactly ONCE here (not once per icon) and passes the resulting
// `now` down as a prop — see useEffectCountdown's doc comment for why that matters.
//
// Filters out anything already past its expiresAt before rendering, using that same `now` —
// matching the old game's EJS rendering, which always recomputed `getActiveEffects()` fresh
// against Date.now() on every render, so a buff simply vanished from the page the instant it
// expired regardless of whether any background sweep had physically removed it yet. Without
// this, the countdown here would freeze at "0" and the icon would keep showing until the next
// state:update push — visibly lagging a couple of seconds behind server clock, exactly the
// "buffs don't disappear correctly" symptom. Expiry stays server-authoritative for game-state
// purposes (stats, regen-blocking) either way; this only ever hides something the server would
// also very shortly agree is gone.
export default function EffectsList({ effects }: EffectsListProps) {
    const now = useEffectCountdown();
    const visible = effects.filter(e => e.expiresAt === undefined || e.expiresAt > now);

    return (
        <>
            {visible.map(effect => (
                <EffectIcon key={effect.id} effect={effect} now={now} />
            ))}
        </>
    );
}
