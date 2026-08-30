import { useEffect, useRef, useState } from 'react';
import type { ClientToServerEvents } from '@shared/contract';
import { request, type AckedEvent, type AckDataOf } from './client';
import { useGameStore } from '@/store/gameStore';

interface UseRequestResult<K extends AckedEvent> {
    /** `undefined` until the first successful load — NOT the same as "loaded, but empty". */
    data: AckDataOf<K> | undefined;
    loading: boolean;
}

/**
 * The read-side sibling to `useAction`: fetches on mount and whenever the payload changes.
 *
 * `loading` starts TRUE, unlike `useAction`'s `pending` — that one is driven by a click, this one
 * by a mount, so its very first render is already in flight. Keeping the two distinct is the whole
 * point: a screen that cannot tell "still loading" from "came back empty" ends up confidently
 * telling the player there is nothing there while the request is still on the wire.
 *
 * `data` is deliberately RETAINED across a re-fetch, so a screen that re-queries with new
 * arguments (the highscores race filter) keeps showing the previous results instead of blanking.
 *
 * A failure surfaces through the shared notice banner and leaves `data` untouched. Read via
 * `getState()` rather than a subscription, matching `useAction`, so `setNotice` stays out of the
 * effect's dependencies.
 */
export function useRequest<K extends AckedEvent>(
    event: K,
    payload: Parameters<ClientToServerEvents[K]>[0],
): UseRequestResult<K> {
    const [data, setData] = useState<AckDataOf<K> | undefined>(undefined);
    const [loading, setLoading] = useState(true);

    // Compared by value: both call sites pass a fresh object literal every render, so an identity
    // dependency would re-fetch forever.
    const payloadKey = JSON.stringify(payload);
    const payloadRef = useRef(payload);
    payloadRef.current = payload;

    useEffect(() => {
        let cancelled = false;
        setLoading(true);

        void request(event, payloadRef.current).then(res => {
            if (cancelled)
                return;

            if (res.ok)
                setData(res.data);
            else
                useGameStore.getState().setNotice(res.error);

            setLoading(false);
        });

        return () => { cancelled = true; };
    }, [event, payloadKey]);

    return { data, loading };
}
