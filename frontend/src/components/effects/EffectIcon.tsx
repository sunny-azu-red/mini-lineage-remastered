import type { EffectView } from '@shared/contract';
import { formatEffectTimer } from '@shared/format';

interface EffectIconProps {
    effect: EffectView;
    /** The shared tick from EffectsList's single useEffectCountdown() call. */
    now: number;
}

// The markup shape is ported verbatim so the existing effect-icon CSS applies unmodified.
export default function EffectIcon({ effect, now }: EffectIconProps) {
    const remSec = effect.expiresAt !== undefined ? Math.max(0, Math.ceil((effect.expiresAt - now) / 1000)) : null;

    return (
        <span
            className={`effect-icon effect-fade-in${effect.type ? ` effect-${effect.type}` : ''}`}
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
