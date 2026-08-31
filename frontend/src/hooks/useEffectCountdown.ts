import { useEffect, useState } from 'react';
import { useGameStore } from '@/store/gameStore';

/**
 * One shared `now` tick. Call ONCE from `EffectsList` and pass the value down, so the effects row
 * uses a single interval total; each icon derives its own remaining time from it.
 *
 * The interval exists only to guarantee a render at least once a second — it is deliberately NOT
 * the source of `now`. Holding `now` in state instead meant it was re-sampled only when the
 * interval fired, so a render caused by anything else (a server push adding an effect) measured
 * against a timestamp up to a full second old. `Math.ceil` then rounded that inflated remainder
 * up, and a 5-second effect opened its countdown on 6 — or 7 when the browser delayed the timer.
 *
 * Reading the clock here makes the hook impure, which is correct: a clock is not a function of
 * state. React's development double-render gets two timestamps a fraction of a millisecond apart,
 * which a whole-second countdown cannot show.
 *
 * The value returned is SERVER time, not local time: `expiresAt` is stamped by the server, so
 * comparing it against this machine's clock would let any skew between the two shift every timer.
 * Subscribing to the offset (rather than reading it once) means the row re-renders the moment a
 * measurement lands, instead of showing an uncorrected countdown until the next interval tick.
 */
export function useEffectCountdown(intervalMs: number = 1000): number {
    const clockOffsetMs = useGameStore(state => state.clockOffsetMs);
    const [, tick] = useState(0);

    useEffect(() => {
        const id = setInterval(() => tick(n => n + 1), intervalMs);
        return () => clearInterval(id);
    }, [intervalMs]);

    return Date.now() + clockOffsetMs;
}
