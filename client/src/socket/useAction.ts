import { useCallback, useRef, useState } from 'react';
import type { Ack, ClientToServerEvents } from '@shared/contract';
import { request } from './client';
import { useGameStore } from '@/store/gameStore';

/** Every `ClientToServerEvents` key that acks — i.e. every one except the fire-and-forget `input` relay. */
type MutatingEvent = Exclude<keyof ClientToServerEvents, 'input'>;

type AckDataOf<K extends MutatingEvent> = ClientToServerEvents[K] extends (
    payload: any,
    ack: (r: Ack<infer TData>) => void,
) => void
    ? TData
    : never;

interface UseActionOptions<TData> {
    onSuccess?: (data: TData) => void;
}

interface UseActionResult<K extends MutatingEvent> {
    pending: boolean;
    run: (payload: Parameters<ClientToServerEvents[K]>[0], opts?: UseActionOptions<AckDataOf<K>>) => Promise<void>;
}

/**
 * Replaces the old global 3s button-disable debounce hack (`.btn-disabled` toggled by hand,
 * plus a `setTimeout` to re-enable) entirely — no timers, no CSS classes, just a `pending` flag
 * that a caller wires straight to a button's `disabled` prop.
 *
 * A `useRef` (not just the `pending` state) guards re-entrancy: two `run()` calls issued in the
 * same synchronous tick (e.g. a fast double-click before React has re-rendered with the new
 * `pending` state) must still only fire one request — a plain `if (pending) return` closed over
 * stale state would not catch that.
 */
export function useAction<K extends MutatingEvent>(event: K): UseActionResult<K> {
    const [pending, setPending] = useState(false);
    const pendingRef = useRef(false);

    const run = useCallback(
        async (
            payload: Parameters<ClientToServerEvents[K]>[0],
            opts?: UseActionOptions<AckDataOf<K>>,
        ): Promise<void> => {
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
