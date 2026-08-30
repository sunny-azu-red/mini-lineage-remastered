import { useEffect, useRef, useState } from 'react';

const DEFAULT_DURATION_MS = 600;

export interface UseAnimatedNumberOptions {
    durationMs?: number;
    format?: (n: number) => string;
}

function prefersReducedMotion(): boolean {
    try {
        return window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    } catch {
        // matchMedia unavailable (e.g. an unstubbed test environment) — animate normally.
        return false;
    }
}

/**
 * Eases a displayed number toward `target` on the same cubic curve the old vanilla script used.
 *
 * The "from" value is seeded with the FIRST target this instance ever sees, so the initial render
 * (including right after a reconnect) shows the true value instantly with no 0→N sweep. That is
 * what replaces the old sessionStorage cache + pre-paint style-injection hack: there is no reload
 * here, so the previous value simply lives in memory across renders.
 */
export function useAnimatedNumber(
    target: number,
    opts?: UseAnimatedNumberOptions,
): { display: string; direction: -1 | 0 | 1 } {
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
            startTs ??= ts;
            const progress = Math.min((ts - startTs) / durationMs, 1);

            if (progress < 1) {
                setCurrent(from + (1 - Math.pow(1 - progress, 3)) * (target - from));
                rafRef.current = requestAnimationFrame(step);
            } else {
                setCurrent(target);
                rafRef.current = null;
            }
        };
        rafRef.current = requestAnimationFrame(step);

        // Cancelling here is what stops two animations overlapping when retargeted mid-flight:
        // React always runs this cleanup before re-running the effect.
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
