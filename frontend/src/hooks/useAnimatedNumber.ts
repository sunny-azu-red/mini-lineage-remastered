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
        return false;
    }
}

/**
 * Eases a displayed number toward `target` on a cubic curve. The "from" value is seeded with the
 * FIRST target this instance ever sees, so the initial render (including right after a reconnect)
 * shows the true value instantly with no 0→N sweep.
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

        // Runs before every re-run, so two animations retargeted mid-flight never overlap.
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
