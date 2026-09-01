import { useEffect, useRef, useState } from 'react';
import type { ClientToServerEvents } from '@shared/contract';
import { request, type AckedEvent, type AckDataOf } from './client';
import { useGameStore } from '@/store/gameStore';

interface UseRequestResult<K extends AckedEvent> {
    /** `undefined` until the first successful load — NOT the same as "loaded, but empty". */
    data: AckDataOf<K> | undefined;
    loading: boolean;
}

// The read-side sibling to `useAction`: fetches on mount and whenever the payload changes.
// `loading` starts TRUE, unlike `useAction`'s `pending`, since a mount is already in flight.
// `data` is RETAINED across a re-fetch, so re-querying with new args doesn't blank old results.
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
