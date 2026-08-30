import { useEffect, useRef, useState } from 'react';

const DEFAULT_SHIMMER_MS = 600; // matches components.css's bar-shimmer-sweep window

/**
 * True for `ms` whenever `trigger` changes. A React re-render is enough to restart the
 * `.shimmer-active` CSS animation, so none of the old remove-class/force-reflow/add-class dance
 * is needed.
 *
 * The first run is deliberately NOT a "change": callers advance `trigger` only on a real HP/XP
 * gain, so without this guard mounting the sidebar would always shimmer once.
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
