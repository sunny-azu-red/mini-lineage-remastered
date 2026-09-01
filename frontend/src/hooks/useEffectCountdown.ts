import { useEffect, useState } from 'react';

/**
 * One shared `now` tick — call ONCE from `EffectsList` and pass the value down, so the effects
 * row uses a single interval total. The interval only guarantees a render at least once a second;
 * `now` itself is read fresh (impure) on every call, not cached in state, so a render triggered by
 * anything else (a server push) never measures against a stale, up-to-a-second-old timestamp.
 */
export function useEffectCountdown(intervalMs: number = 1000): number {
    const [, tick] = useState(0);

    useEffect(() => {
        const id = setInterval(() => tick(n => n + 1), intervalMs);
        return () => clearInterval(id);
    }, [intervalMs]);

    return Date.now();
}
