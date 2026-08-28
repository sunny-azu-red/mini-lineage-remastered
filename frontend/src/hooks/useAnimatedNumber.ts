import { useEffect, useRef, useState } from 'react';

const DEFAULT_DURATION_MS = 600; // matches public/js/common.js's ANIMATION_DURATION_MS

export interface UseAnimatedNumberOptions {
    durationMs?: number;
    format?: (n: number) => string;
}

export interface UseAnimatedNumberResult {
    display: string;
    direction: -1 | 0 | 1;
}

function prefersReducedMotion(): boolean {
    try {
        return window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    } catch {
        // matchMedia unavailable (e.g. a test environment without it stubbed) — animate normally.
        return false;
    }
}

/**
 * Animates a displayed number toward `target` using the same cubic ease-out curve proven in
 * public/js/common.js's `animateValue` (`1 - Math.pow(1 - p, 3)`), reimplemented as a hook that
 * needs no DOM element handle and no sessionStorage/pre-paint hack to know its starting point.
 *
 * The "from" value is seeded with the FIRST `target` this hook instance ever receives (via a
 * ref, initialized lazily on the first effect run) — so the very first render (including right
 * after a `hydrate` reconnect) shows the true value INSTANTLY with no 0→N sweep. This is the one
 * behavior that fully replaces the old sessionStorage `mini_last_*` cache + pre-paint `<head>`
 * style-injection hack in layout.ejs/sidebar.js: there is no reload here, so the "previous value"
 * is simply held in-memory across renders instead of being faked from a stale cache.
 */
export function useAnimatedNumber(
    target: number,
    opts?: UseAnimatedNumberOptions,
): UseAnimatedNumberResult {
    const durationMs = opts?.durationMs ?? DEFAULT_DURATION_MS;
    const format = opts?.format ?? ((n: number) => n.toLocaleString());

    const prevTargetRef = useRef<number | null>(null);
    const rafRef = useRef<number | null>(null);
    const [current, setCurrent] = useState(target);
    const [direction, setDirection] = useState<-1 | 0 | 1>(0);

    useEffect(() => {
        const isFirst = prevTargetRef.current === null;
        const from = isFirst ? target : prevTargetRef.current!;
        prevTargetRef.current = target;

        // Cancel any in-flight rAF loop before starting a new one — the exact guard mechanism
        // common.js's animateValue uses (`if (el.__animId) cancelAnimationFrame(el.__animId)`)
        // so two overlapping animations never step on each other when retargeted mid-flight.
        if (rafRef.current !== null) {
            cancelAnimationFrame(rafRef.current);
            rafRef.current = null;
        }

        if (from === target) {
            setCurrent(target);
            setDirection(0);
            return;
        }

        setDirection(target > from ? 1 : -1);

        if (isFirst || prefersReducedMotion()) {
            setCurrent(target);
            return;
        }

        let startTs: number | null = null;
        const step = (ts: number) => {
            if (startTs === null)
                startTs = ts;

            const progress = Math.min((ts - startTs) / durationMs, 1);
            const eased = 1 - Math.pow(1 - progress, 3);
            const value = from + eased * (target - from);

            if (progress < 1) {
                setCurrent(value);
                rafRef.current = requestAnimationFrame(step);
            } else {
                setCurrent(target);
                rafRef.current = null;
            }
        };
        rafRef.current = requestAnimationFrame(step);

        return () => {
            if (rafRef.current !== null) {
                cancelAnimationFrame(rafRef.current);
                rafRef.current = null;
            }
        };
        // eslint-disable-next-line react-hooks/exhaustive-deps
    }, [target, durationMs]);

    return { display: format(Math.round(current)), direction };
}
