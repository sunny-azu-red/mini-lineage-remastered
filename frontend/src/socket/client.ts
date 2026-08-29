import { io, Socket } from 'socket.io-client';
import type { Ack, ClientToServerEvents, ServerToClientEvents } from '@shared/contract';

export const socket: Socket<ServerToClientEvents, ClientToServerEvents> = io({
    autoConnect: false,
});

/**
 * Forces a session cookie to exist before the first `io()` connect (plan decision A10):
 * express-session's `saveUninitialized:false` combined with Socket.IO's mock `res` object means
 * a socket-only session can never receive a `Set-Cookie`. Must be awaited once before
 * `connectSocket()`.
 */
export async function bootstrapSession(): Promise<void> {
    await fetch('/api/bootstrap', { credentials: 'same-origin' });
}

export function connectSocket(): void {
    socket.connect();
}

/** Every ClientToServerEvents key except the fire-and-forget `input` relay. */
type MutatingEvents = Exclude<keyof ClientToServerEvents, 'input'>;

type AckDataOf<K extends MutatingEvents> = ClientToServerEvents[K] extends (
    payload: any,
    ack: (r: Ack<infer TData>) => void,
) => void
    ? TData
    : never;

/**
 * Typed wrapper around `socket.timeout(...).emitWithAck(...)`. Callers never need their own
 * try/catch — a transport-level failure (including a server that never acks in time) resolves
 * to a normal `Ack<T>` failure value instead of throwing.
 *
 * The call site's signature (`event`/`payload` in, `Ack<AckDataOf<K>>` out) is fully typed
 * against `ClientToServerEvents`. Internally, socket.io-client's own generic inference for
 * `emitWithAck` on a variable (rather than literal) event name doesn't collapse cleanly with a
 * generic `K` here, so the actual call is loosened to `any` — this is an implementation detail,
 * not a hole in the public contract above.
 */
export async function request<K extends MutatingEvents>(
    event: K,
    payload: Parameters<ClientToServerEvents[K]>[0],
): Promise<Ack<AckDataOf<K>>> {
    try {
        const untypedSocket = socket as unknown as {
            timeout(ms: number): { emitWithAck(event: string, payload: unknown): Promise<Ack<AckDataOf<K>>>; };
        };
        return await untypedSocket.timeout(10_000).emitWithAck(event, payload);
    } catch {
        return {
            ok: false,
            error: { code: 'INTERNAL', message: '⭕ You got disconnected from the realm, the backend is offline.' },
        };
    }
}
