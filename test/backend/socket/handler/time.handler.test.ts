import { describe, it, expect, vi, beforeEach } from 'vitest';
import type { Server as SocketIOServer, Socket } from 'socket.io';
import type { TimeSyncResponse } from '@shared/contract';

vi.mock('@/socket/registry', () => ({ registerEvent: vi.fn() }));

import { registerEvent } from '@/socket/registry';
import { registerTimeHandlers } from '@/socket/handler/time.handler';

/**
 * Feeds the client's SNTP offset estimate (frontend/src/socket/clock.ts). The handler must do as
 * little as possible: anything it computes lands between the two timestamps it reports.
 */
describe('time:sync handler', () => {
    const io = {} as SocketIOServer;
    const socket = {} as Socket;

    beforeEach(() => {
        vi.mocked(registerEvent).mockReset();
    });

    /** The definition the handler registers, so its shape and handler can be asserted directly. */
    function definition() {
        registerTimeHandlers(io, socket);
        expect(registerEvent).toHaveBeenCalledTimes(1);

        return vi.mocked(registerEvent).mock.calls[0][2];
    }

    it('registers a read-only event with no guards and no rate limit of its own', () => {
        const def = definition();

        expect(def.event).toBe('time:sync');
        expect(def.mode).toBe('read');
        // Public on purpose: a visitor with no character still renders effect timers, and a clock
        // reading is not privileged. `requireStarted` would reject it and log an error.
        expect(def.guards).toBeUndefined();
        expect(def.rateLimit).toBeUndefined();
    });

    it('answers with both server timestamps, in order', () => {
        const def = definition();
        const before = Date.now();

        const result = def.handler({} as any, {} as any) as TimeSyncResponse;

        const after = Date.now();
        expect(result.receivedAt).toBeGreaterThanOrEqual(before);
        expect(result.sentAt).toBeGreaterThanOrEqual(result.receivedAt);
        expect(result.sentAt).toBeLessThanOrEqual(after);
    });

    it('reads the clock rather than returning a constant', () => {
        const def = definition();
        vi.spyOn(Date, 'now').mockReturnValueOnce(111).mockReturnValueOnce(222);

        expect(def.handler({} as any, {} as any)).toEqual({ receivedAt: 111, sentAt: 222 });

        vi.restoreAllMocks();
    });
});
