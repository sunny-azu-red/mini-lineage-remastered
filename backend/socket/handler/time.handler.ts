import type { Server as SocketIOServer, Socket } from 'socket.io';
import type { TimeSyncResponse } from '@shared/contract';
import { registerEvent } from '../registry';
import { EmptyPayloadSchema } from '@/schema/socket.schema';

/**
 * Clock exchange, so the client can count an effect's `expiresAt` — an absolute SERVER epoch —
 * down against the server's clock rather than its own. See frontend/src/socket/clock.ts for the
 * estimate this feeds.
 *
 * Public, with no guards: a visitor with no character still renders effect timers the moment one
 * exists, and a clock reading is not privileged information.
 */
export function registerTimeHandlers(io: SocketIOServer, socket: Socket): void {
    registerEvent(io, socket, {
        event: 'time:sync',
        schema: EmptyPayloadSchema,
        mode: 'read',
        // Deliberately does nothing else. Both timestamps are taken here rather than in the
        // registry, so the small cost of the session load `readSession` performs first is counted
        // as network latency and halved — a millisecond or two against a display that counts whole
        // seconds.
        handler: (): TimeSyncResponse => {
            const receivedAt = Date.now();

            return { receivedAt, sentAt: Date.now() };
        },
    });
}
