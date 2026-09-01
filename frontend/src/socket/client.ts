import { io, Socket } from 'socket.io-client';
import type { Ack, ClientToServerEvents, ServerToClientEvents } from '@shared/contract';

const REQUEST_TIMEOUT_MS = 10_000;

export const socket: Socket<ServerToClientEvents, ClientToServerEvents> = io({ autoConnect: false });

/** Every ClientToServerEvents key that acks — i.e. all but the fire-and-forget `input` relay. */
export type AckedEvent = Exclude<keyof ClientToServerEvents, 'input'>;

export type AckDataOf<K extends AckedEvent> = ClientToServerEvents[K] extends (
    payload: any,
    ack: (r: Ack<infer TData>) => void,
) => void
    ? TData
    : never;

/** Forces a session cookie to exist before the first connect. Must be awaited before connectSocket(). */
export async function bootstrapSession(): Promise<void> {
    await fetch('/api/bootstrap', { credentials: 'same-origin' });
}

export function connectSocket(): void {
    socket.connect();
}

/**
 * Typed wrapper around `emitWithAck`. Callers never need a try/catch — a transport failure
 * resolves to a normal `Ack` failure. Loosened to `any` internally only because socket.io-client's
 * `emitWithAck` inference doesn't collapse on a generic event name.
 */
export async function request<K extends AckedEvent>(
    event: K,
    payload: Parameters<ClientToServerEvents[K]>[0],
): Promise<Ack<AckDataOf<K>>> {
    try {
        const untyped = socket as unknown as {
            timeout(ms: number): { emitWithAck(event: string, payload: unknown): Promise<Ack<AckDataOf<K>>> };
        };

        return await untyped.timeout(REQUEST_TIMEOUT_MS).emitWithAck(event, payload);
    } catch {
        return {
            ok: false,
            error: { code: 'INTERNAL', message: '⭕ You got disconnected from the realm, the backend is offline.' },
        };
    }
}
