import { useEffect, useState } from 'react';

/**
 * A single shared `now` tick, meant to be called ONCE by `EffectsList` and passed down as a prop
 * to each `EffectIcon` — so there is still only one `setInterval` total for the whole effects
 * row, matching the efficiency of socket.js's original single global interval (which walked
 * every `.effect-icon[data-expires-at]` in the DOM once a second). Each `EffectIcon` derives its
 * own remaining-time text from `Math.ceil((expiresAt - now) / 1000)`.
 */
export function useEffectCountdown(intervalMs: number = 1000): number {
    const [now, setNow] = useState(() => Date.now());

    useEffect(() => {
        const id = setInterval(() => setNow(Date.now()), intervalMs);
        return () => clearInterval(id);
    }, [intervalMs]);

    return now;
}
