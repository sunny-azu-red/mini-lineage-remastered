import { describe, it, expect, vi, beforeEach } from 'vitest';
import { z } from 'zod';

const { floodConsumeMock } = vi.hoisted(() => ({
    floodConsumeMock: vi.fn((): { allowed: true } | { allowed: false; retryAfterMs: number } => ({ allowed: true })),
}));

vi.mock('@/socket/rate-limit', () => ({
    floodLimiter: { name: 'flood', consume: floodConsumeMock },
}));

vi.mock('@/socket/session', () => ({
    withSession: vi.fn(),
    readSession: vi.fn(),
}));

vi.mock('@/socket/emitter', () => ({
    emitStateUpdate: vi.fn(),
}));

vi.mock('@/socket/tick', () => ({
    refreshExpiryTimers: vi.fn(),
}));

vi.mock('@/socket/serializer/player.serializer', () => ({
    buildPlayerSnapshot: vi.fn((player: any) => ({ snapshotOf: player })),
}));

import { registerEvent } from '@/socket/registry';
import { withSession, readSession } from '@/socket/session';
import { emitStateUpdate } from '@/socket/emitter';
import { refreshExpiryTimers } from '@/socket/tick';
import { SocketError } from '@/socket/error';
import { logger } from '@/config/logger.config';
import type { Guard } from '@/socket/guard';
import type { RateLimiter } from '@/socket/rate-limit';

function makeSocket(sessionId: string | null = 'sid-1') {
    const handlers: Record<string, (...args: any[]) => any> = {};
    const socket = {
        id: 'socket-1',
        on: vi.fn((event: string, cb: (...args: any[]) => any) => { handlers[event] = cb; }),
        request: sessionId !== null ? { session: { id: sessionId } } : {},
    } as any;

    return { socket, handlers };
}

describe('registerEvent', () => {
    const io = {} as any;

    beforeEach(() => {
        vi.clearAllMocks();
        floodConsumeMock.mockReturnValue({ allowed: true });
    });

    it('resolves undefined payload when the caller sends only an ack (arg-normalization)', async () => {
        const handler = vi.fn().mockResolvedValue('ok');
        vi.mocked(withSession).mockImplementation(async (_sid: string, run: any) =>
            run({ sessionId: 'sid-1', session: {}, player: {} }));

        const { socket, handlers } = makeSocket();
        registerEvent(io, socket, {
            event: 'test:empty',
            schema: z.object({}).strict().default({}),
            mode: 'mutate',
            handler,
        });

        const ack = vi.fn();
        await handlers['test:empty'](ack); // only the ack, no payload argument at all

        expect(handler).toHaveBeenCalledWith(expect.anything(), {});
        expect(ack).toHaveBeenCalledWith({ ok: true, data: 'ok' });
    });

    it('treats the sole argument as payload (no ack) for fire-and-forget events like input', async () => {
        const handler = vi.fn().mockResolvedValue('ignored');
        vi.mocked(withSession).mockImplementation(async (_sid: string, run: any) =>
            run({ sessionId: 'sid-1', session: {}, player: {} }));

        const { socket, handlers } = makeSocket();
        registerEvent(io, socket, {
            event: 'test:fireforget',
            schema: z.object({ key: z.string() }),
            mode: 'mutate',
            handler,
        });

        await expect(handlers['test:fireforget']({ key: 'x' })).resolves.not.toThrow();
        expect(handler).toHaveBeenCalledWith(expect.anything(), { key: 'x' });
    });

    it('acks UNAUTHENTICATED when there is no session id on the handshake', async () => {
        const { socket, handlers } = makeSocket(null);
        registerEvent(io, socket, {
            event: 'test:auth',
            schema: z.object({}).default({}),
            mode: 'read',
            handler: vi.fn(),
        });

        const warnSpy = vi.spyOn(logger, 'warn').mockImplementation(() => undefined as any);
        const ack = vi.fn();
        await handlers['test:auth']({}, ack);

        expect(ack).toHaveBeenCalledWith({ ok: false, error: expect.objectContaining({ code: 'UNAUTHENTICATED' }) });
        expect(withSession).not.toHaveBeenCalled();
        expect(readSession).not.toHaveBeenCalled();
        // WARN, not just the generic per-event DEBUG log — matches the old game exactly, and
        // matters because pino's level rises to 'info' in a release build (silencing .debug()
        // entirely), so this must survive that filter to stay visible in production.
        expect(warnSpy).toHaveBeenCalledWith(`[SOCKET] Unauthenticated event 'test:auth' from socket socket-1`);
        warnSpy.mockRestore();
    });

    it('acks INVALID_PAYLOAD when Zod rejects the payload, without touching the session', async () => {
        const { socket, handlers } = makeSocket();
        registerEvent(io, socket, {
            event: 'test:invalid',
            schema: z.object({ n: z.number() }),
            mode: 'mutate',
            handler: vi.fn(),
        });

        const warnSpy = vi.spyOn(logger, 'warn').mockImplementation(() => undefined as any);
        const ack = vi.fn();
        await handlers['test:invalid']({ n: 'not a number' }, ack);

        expect(ack).toHaveBeenCalledWith({ ok: false, error: expect.objectContaining({ code: 'INVALID_PAYLOAD' }) });
        expect(withSession).not.toHaveBeenCalled();
        expect(warnSpy).toHaveBeenCalledWith(
            { err: expect.anything() },
            `[SOCKET] Invalid payload for event 'test:invalid' from socket socket-1`,
        );
        warnSpy.mockRestore();
    });

    it('maps a thrown guard SocketError to its code via the ack', async () => {
        const throwingGuard: Guard = () => { throw new SocketError('DEAD', 'you are dead'); };
        vi.mocked(withSession).mockImplementation(async (_sid: string, run: any) => run({ sessionId: 'sid-1', session: {}, player: {} }));

        const { socket, handlers } = makeSocket();
        registerEvent(io, socket, {
            event: 'test:guarded',
            schema: z.object({}).default({}),
            mode: 'mutate',
            guards: [throwingGuard],
            handler: vi.fn(),
        });

        const ack = vi.fn();
        await handlers['test:guarded']({}, ack);

        expect(ack).toHaveBeenCalledWith({ ok: false, error: expect.objectContaining({ code: 'DEAD' }) });
        expect(emitStateUpdate).not.toHaveBeenCalled();
    });

    it('short-circuits on the flood limiter before ever touching the session', async () => {
        floodConsumeMock.mockReturnValue({ allowed: false, retryAfterMs: 2500 });
        const { socket, handlers } = makeSocket();
        registerEvent(io, socket, {
            event: 'test:flooded',
            schema: z.object({}).default({}),
            mode: 'mutate',
            handler: vi.fn(),
        });

        const ack = vi.fn();
        await handlers['test:flooded']({}, ack);

        expect(ack).toHaveBeenCalledWith({
            ok: false,
            error: expect.objectContaining({ code: 'RATE_LIMITED', retryAfterMs: 2500 }),
        });
        expect(withSession).not.toHaveBeenCalled();
    });

    it('short-circuits on a per-event rate limiter', async () => {
        const rateLimit: RateLimiter = { name: 'custom', consume: vi.fn(() => ({ allowed: false, retryAfterMs: 999 })) };
        const { socket, handlers } = makeSocket();
        registerEvent(io, socket, {
            event: 'test:custom-limited',
            schema: z.object({}).default({}),
            mode: 'mutate',
            rateLimit,
            handler: vi.fn(),
        });

        const ack = vi.fn();
        await handlers['test:custom-limited']({}, ack);

        expect(ack).toHaveBeenCalledWith({
            ok: false,
            error: expect.objectContaining({ code: 'RATE_LIMITED', retryAfterMs: 999 }),
        });
    });

    it('emits state:update exactly once to sync other tabs on a successful mutation', async () => {
        const player = { health: 42 };
        vi.mocked(withSession).mockImplementation(async (sid: string, run: any) =>
            run({ sessionId: sid, session: {}, player }));

        const { socket, handlers } = makeSocket();
        registerEvent(io, socket, {
            event: 'test:mutate-ok',
            schema: z.object({}).default({}),
            mode: 'mutate',
            handler: vi.fn().mockReturnValue({ result: true }),
        });

        const ack = vi.fn();
        await handlers['test:mutate-ok']({}, ack);

        expect(emitStateUpdate).toHaveBeenCalledTimes(1);
        // The acting socket's own id is passed through as the exclusion — it already gets this
        // exact result via its own ack (see emitStateUpdate's doc comment: this used to be a
        // race, see git history).
        expect(emitStateUpdate).toHaveBeenCalledWith(io, 'sid-1', { snapshotOf: player }, 'socket-1');
        expect(ack).toHaveBeenCalledWith({ ok: true, data: { result: true } });
    });

    it('refreshes exact expiry timers for the acting session on a successful mutation (Fix 2)', async () => {
        // Closes the wiring gap: a fresh expiresAt set during a mutation (e.g. a food buff
        // applied via shop:purchase, see player.service.ts's applyEffect) must be scheduled
        // immediately, not sit unscheduled until the next periodic tick/reconnect.
        const player = { health: 42 };
        vi.mocked(withSession).mockImplementation(async (sid: string, run: any) =>
            run({ sessionId: sid, session: {}, player }));

        const { socket, handlers } = makeSocket();
        registerEvent(io, socket, {
            event: 'test:mutate-refresh',
            schema: z.object({}).default({}),
            mode: 'mutate',
            handler: vi.fn().mockReturnValue({ result: true }),
        });

        const ack = vi.fn();
        await handlers['test:mutate-refresh']({}, ack);

        expect(refreshExpiryTimers).toHaveBeenCalledTimes(1);
        expect(refreshExpiryTimers).toHaveBeenCalledWith(io, 'sid-1', player);
    });

    it('does not refresh expiry timers for a read-mode handler', async () => {
        vi.mocked(readSession).mockImplementation(async (sid: string, run: any) =>
            run({ sessionId: sid, session: {}, player: {} }));

        const { socket, handlers } = makeSocket();
        registerEvent(io, socket, {
            event: 'test:read-ok-2',
            schema: z.object({}).default({}),
            mode: 'read',
            handler: vi.fn().mockReturnValue({ result: true }),
        });

        const ack = vi.fn();
        await handlers['test:read-ok-2']({}, ack);

        expect(refreshExpiryTimers).not.toHaveBeenCalled();
    });

    it('does not refresh expiry timers when a mutation throws before persisting', async () => {
        vi.mocked(withSession).mockImplementation(async (_sid: string, run: any) =>
            run({ sessionId: 'sid-1', session: {}, player: {} }));

        const { socket, handlers } = makeSocket();
        registerEvent(io, socket, {
            event: 'test:mutate-throw',
            schema: z.object({}).default({}),
            mode: 'mutate',
            handler: () => { throw new SocketError('DEAD', 'you are dead'); },
        });

        const ack = vi.fn();
        await handlers['test:mutate-throw']({}, ack);

        expect(refreshExpiryTimers).not.toHaveBeenCalled();
    });

    it('does not emit state:update for a read-mode handler', async () => {
        vi.mocked(readSession).mockImplementation(async (sid: string, run: any) =>
            run({ sessionId: sid, session: {}, player: {} }));

        const { socket, handlers } = makeSocket();
        registerEvent(io, socket, {
            event: 'test:read-ok',
            schema: z.object({}).default({}),
            mode: 'read',
            handler: vi.fn().mockReturnValue({ result: true }),
        });

        const ack = vi.fn();
        await handlers['test:read-ok']({}, ack);

        expect(emitStateUpdate).not.toHaveBeenCalled();
        expect(withSession).not.toHaveBeenCalled();
        expect(ack).toHaveBeenCalledWith({ ok: true, data: { result: true } });
    });

    it('acks a generic INTERNAL error for an unexpected handler throw, without leaking details', async () => {
        vi.mocked(withSession).mockImplementation(async (_sid: string, run: any) =>
            run({ sessionId: 'sid-1', session: {}, player: {} }));

        const { socket, handlers } = makeSocket();
        registerEvent(io, socket, {
            event: 'test:boom',
            schema: z.object({}).default({}),
            mode: 'mutate',
            handler: () => { throw new Error('leaked internal detail'); },
        });

        const ack = vi.fn();
        await handlers['test:boom']({}, ack);

        const [[response]] = ack.mock.calls;
        expect(response.ok).toBe(false);
        expect(response.error.code).toBe('INTERNAL');
        expect(JSON.stringify(response)).not.toContain('leaked internal detail');
    });
});
