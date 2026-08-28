import type { EffectView } from '@shared/contract';
import { useEffectCountdown } from '@/hooks/useEffectCountdown';
import EffectIcon from './EffectIcon';

interface EffectsListProps {
    effects: EffectView[];
}

// Calls useEffectCountdown() exactly ONCE here (not once per icon) and passes the resulting
// `now` down as a prop — see useEffectCountdown's doc comment for why that matters.
export default function EffectsList({ effects }: EffectsListProps) {
    const now = useEffectCountdown();

    return (
        <>
            {effects.map(effect => (
                <EffectIcon key={effect.id} effect={effect} now={now} />
            ))}
        </>
    );
}
