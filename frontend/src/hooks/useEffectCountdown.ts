import { useEffect, useState } from 'react';

/**
 * One shared `now` tick. Call ONCE from `EffectsList` and pass the value down, so the effects row
 * uses a single interval total; each icon derives its own remaining time from it.
 */
export function useEffectCountdown(intervalMs: number = 1000): number {
    const [now, setNow] = useState(() => Date.now());

    useEffect(() => {
        const id = setInterval(() => setNow(Date.now()), intervalMs);
        return () => clearInterval(id);
    }, [intervalMs]);

    return now;
}
