import type { EffectView } from '@shared/contract';
import { formatEffectTimer } from '@shared/format';

interface EffectIconProps {
    effect: EffectView;
    /** Milliseconds since the snapshot carrying this effect landed. From EffectsList. */
    elapsed: number;
}

// The markup shape is ported verbatim so the existing effect-icon CSS applies unmodified.
export default function EffectIcon({ effect, elapsed }: EffectIconProps) {
    // `remainingMs` is a duration measured by the server, counted down against time elapsed on THIS
    // machine since it arrived. Nothing compares the two clocks, so `remaining` can never exceed the
    // effect's real length and `Math.ceil` can never report a second that does not exist.
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
