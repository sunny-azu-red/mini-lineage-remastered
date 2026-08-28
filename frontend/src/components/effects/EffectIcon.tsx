import type { EffectView } from '@shared/contract';
import { formatEffectTimer } from '@shared/format';

interface EffectIconProps {
    effect: EffectView;
    /** Shared tick from EffectsList's single useEffectCountdown() call — see that hook's doc. */
    now: number;
}

// Mirrors src/view/layout.view.ts's renderEffects() markup shape exactly, so the ported CSS
// (.effect-icon / .effect-fade-in / .effect-{type} / .effect-emoji / .effect-timer) still
// applies unmodified.
export default function EffectIcon({ effect, now }: EffectIconProps) {
    const typeClass = effect.type ? ` effect-${effect.type}` : '';

    const remSec = effect.expiresAt !== undefined
        ? Math.max(0, Math.ceil((effect.expiresAt - now) / 1000))
        : null;

    return (
        <span
            className={`effect-icon effect-fade-in${typeClass}`}
            data-effect-id={effect.id}
            data-label={effect.label}
            data-expires-at={effect.expiresAt}
            title={effect.tooltip}
        >
            <span className="effect-emoji">{effect.emoji}</span>
            {remSec !== null && <span className="effect-timer">{formatEffectTimer(remSec)}</span>}
        </span>
    );
}
