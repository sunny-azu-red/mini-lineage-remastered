import { useCallback, useRef, useState } from 'react';
import type { Ack, ClientToServerEvents } from '@shared/contract';
import { request, type AckedEvent, type AckDataOf } from './client';
import { useGameStore } from '@/store/gameStore';

interface UseActionResult<K extends AckedEvent> {
    pending: boolean;
    run: (
        payload: Parameters<ClientToServerEvents[K]>[0],
        opts?: { onSuccess?: (data: AckDataOf<K>) => void },
    ) => Promise<void>;
}

/**
 * Wraps one mutating socket action with a `pending` flag a caller wires straight to a button's
 * `disabled` prop — replacing the old global 3s button-disable hack entirely.
 *
 * The `useRef` (not just `pending`) is what guards re-entrancy: two `run()` calls in the same
 * synchronous tick (a fast double-click before React re-renders) must still fire one request,
 * which a plain `if (pending)` closed over stale state would not catch.
 */
export function useAction<K extends AckedEvent>(event: K): UseActionResult<K> {
    const [pending, setPending] = useState(false);
    const pendingRef = useRef(false);

    const run = useCallback<UseActionResult<K>['run']>(
        async (payload, opts) => {
            if (pendingRef.current)
                return;

            pendingRef.current = true;
            setPending(true);

            const res = (await request(event, payload as any)) as Ack<AckDataOf<K>>;

            pendingRef.current = false;
            setPending(false);

            if (!res.ok) {
                useGameStore.getState().setNotice(res.error);
                return;
            }

            opts?.onSuccess?.(res.data);
        },
        [event],
    );

    return { run, pending };
}
