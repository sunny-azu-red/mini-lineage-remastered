import type { EffectView } from '@shared/contract';
import { formatEffectTimer } from '@shared/format';

interface EffectIconProps {
    effect: EffectView;
    /** Milliseconds since the snapshot carrying this effect landed. From EffectsList. */
    elapsed: number;
}

export default function EffectIcon({ effect, elapsed }: EffectIconProps) {
    // remainingMs is a duration measured by the server, counted down against elapsed local time —
    // nothing compares two clocks, so this can never report a second that doesn't exist.
    const remSec = effect.remainingMs === undefined
        ? null
        : Math.max(0, Math.ceil((effect.remainingMs - elapsed) / 1000));

    return (
        <span
            className={`effect-icon effect-fade-in${effect.type ? ` effect-${effect.type}` : ''}`}
            data-effect-id={effect.id}
            data-label={effect.label}
            data-remaining-ms={effect.remainingMs}
            title={effect.tooltip}
        >
            <span className="effect-emoji">{effect.emoji}</span>
            {remSec !== null && <span className="effect-timer">{formatEffectTimer(remSec)}</span>}
        </span>
    );
}
