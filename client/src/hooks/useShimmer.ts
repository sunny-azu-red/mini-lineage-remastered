import { useEffect, useRef, useState } from 'react';

const DEFAULT_SHIMMER_MS = 600; // matches components.css's bar-shimmer-sweep/ANIMATION_DURATION_MS window

/**
 * Returns `true` for `ms` whenever `trigger` changes, then resets to `false`. Replaces
 * sidebar.js's/socket.js's `classList.remove('shimmer-active')` + `void el.offsetWidth` forced
 * reflow + `classList.add('shimmer-active')` dance: a React re-render triggered by state change
 * is sufficient to restart the `.shimmer-active` CSS animation (see `.hp-bar.shimmer-active`/
 * `.xp-bar.shimmer-active` in components.css) — no manual reflow hack needed.
 *
 * The very first render is deliberately NOT treated as a "change" (a ref-tracked guard skips the
 * first effect run) — callers pass a trigger value that only advances on an actual HP/XP gain
 * (see HpBar/XpBar), so without this guard mounting the sidebar would always shimmer once, which
 * never happened in the original page-load-per-action app.
 */
export function useShimmer(trigger: unknown, ms: number = DEFAULT_SHIMMER_MS): boolean {
    const [active, setActive] = useState(false);
    const isFirstRun = useRef(true);

    useEffect(() => {
        if (isFirstRun.current) {
            isFirstRun.current = false;
            return;
        }

        setActive(true);
        const id = setTimeout(() => setActive(false), ms);
        return () => clearTimeout(id);
        // eslint-disable-next-line react-hooks/exhaustive-deps
    }, [trigger, ms]);

    return active;
}
