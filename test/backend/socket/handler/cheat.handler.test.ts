import { describe, it, expect, vi, beforeEach } from 'vitest';
import type { Socket, Server as SocketIOServer } from 'socket.io';

const { floodConsumeMock } = vi.hoisted(() => ({
    floodConsumeMock: vi.fn((): { allowed: true } | { allowed: false; retryAfterMs: number } => ({ allowed: true })),
}));

vi.mock('@/socket/rate-limit', () => ({
    floodLimiter: { name: 'flood', consume: floodConsumeMock },
}));

vi.mock('@/socket/session', async (importOriginal) => {
    const actual = await importOriginal<typeof import('@/socket/session')>();
    return { ...actual, withSession: vi.fn() };
});

vi.mock('@/socket/emitter', () => ({
    sessionTracker: new Map(),
    emitStateUpdate: vi.fn(),
}));

vi.mock('@/repository/statistics.repository', () => ({
    statisticsRepository: { increment: vi.fn().mockResolvedValue(undefined) },
}));

import { registerCheatHandler } from '@/socket/handler/cheat.handler';
import { withSession, NO_CHANGE } from '@/socket/session';
import { sessionTracker, emitStateUpdate } from '@/socket/emitter';
import { statisticsRepository } from '@/repository/statistics.repository';
import { CHEAT_CONFIG } from '@/constant/game.constant';
import type { PlayerState, SessionTrackerEntry } from '@/interface';

function makeSocket() {
    const handlers: Record<string, (...args: any[]) => any> = {};
    const socket = {
        id: 'sock-1',
        on: vi.fn((event: string, cb: (...args: any[]) => any) => { handlers[event] = cb; }),
        request: { session: { id: 'sid-1' } },
    } as unknown as Socket;

    return { socket, handlers };
}

function makePlayer(overrides: Partial<PlayerState> = {}): PlayerState {
    return {
        name: 'Hero', raceId: 0, health: 100, adena: 0, experience: 0,
        weaponId: 0, armorId: 0, dead: false, ...overrides,
    } as PlayerState;
}

describe('cheat.handler (input / Konami relay)', () => {
    const io = {} as SocketIOServer;

    beforeEach(() => {
        vi.clearAllMocks();
        floodConsumeMock.mockReturnValue({ allowed: true });
        sessionTracker.clear();
    });

    function withSessionAgainst(player: PlayerState) {
        // Mirrors real withSession's NO_CHANGE -> undefined translation, since only
        // withSession itself is mocked here (NO_CHANGE is imported from the real module).
        vi.mocked(withSession).mockImplementation(async (sid: string, mutate: any) => {
            const result = await mutate({ sessionId: sid, session: {}, player });
            return result === NO_CHANGE ? undefined : result;
        });
    }

    async function sendSequence(handlers: Record<string, any>, keys: readonly string[]) {
        for (const key of keys)
            await handlers['input']({ key });
    }

    it('applies the cheat effect once the full Konami sequence is entered, silently — no flash/notice, matching the old game exactly', async () => {
        const { socket, handlers } = makeSocket();
        sessionTracker.set('sid-1', { socketIds: new Set(['sock-1']), lastSeen: Date.now() } as SessionTrackerEntry);
        const player = makePlayer();
        withSessionAgainst(player);

        registerCheatHandler(io, socket);
        await sendSequence(handlers, CHEAT_CONFIG.konamiSequence);

        expect(player.cheated).toBe(true);
        expect(player.health).toBeGreaterThan(100); // maxHealth after konamiCheat buff
        expect(statisticsRepository.increment).toHaveBeenCalledWith('total_players_cheated');
        // Still broadcasts the resulting state (so the debuff icon/HP change show up in real
        // time, matching the old game's own emitToSession call here) — just with no message.
        expect(emitStateUpdate).toHaveBeenCalledTimes(1);
        expect(emitStateUpdate).toHaveBeenCalledWith(io, 'sid-1', expect.objectContaining({ cheated: true }));
    });

    it('resets the buffer after a completed sequence (case-insensitive keys)', async () => {
        const { socket, handlers } = makeSocket();
        sessionTracker.set('sid-1', { socketIds: new Set(['sock-1']), lastSeen: Date.now() } as SessionTrackerEntry);
        const player = makePlayer();
        withSessionAgainst(player);

        registerCheatHandler(io, socket);
        await sendSequence(handlers, CHEAT_CONFIG.konamiSequence.map(k => k.toUpperCase()));

        expect(player.cheated).toBe(true);
        expect(sessionTracker.get('sid-1')!.inputBuffer).toEqual([]);
    });

    it('does nothing for an incomplete or incorrect sequence', async () => {
        const { socket, handlers } = makeSocket();
        sessionTracker.set('sid-1', { socketIds: new Set(['sock-1']), lastSeen: Date.now() } as SessionTrackerEntry);
        registerCheatHandler(io, socket);

        await sendSequence(handlers, ['arrowup', 'arrowdown', 'b']);

        expect(withSession).not.toHaveBeenCalled();
    });

    it('does not apply the cheat for a dead or not-yet-started player (silent no-op, no ack to report to)', async () => {
        const { socket, handlers } = makeSocket();
        sessionTracker.set('sid-1', { socketIds: new Set(['sock-1']), lastSeen: Date.now() } as SessionTrackerEntry);
        const deadPlayer = makePlayer({ dead: true });
        withSessionAgainst(deadPlayer);

        registerCheatHandler(io, socket);
        await sendSequence(handlers, CHEAT_CONFIG.konamiSequence);

        expect(deadPlayer.cheated).toBeUndefined();
        expect(emitStateUpdate).not.toHaveBeenCalled();
    });

    it('does nothing when there is no session id on the handshake', async () => {
        const { handlers } = (() => {
            const h: Record<string, any> = {};
            const socket = {
                id: 'sock-2',
                on: vi.fn((event: string, cb: any) => { h[event] = cb; }),
                request: {},
            } as unknown as Socket;
            registerCheatHandler(io, socket);
            return { handlers: h };
        })();

        await expect(sendSequence(handlers, CHEAT_CONFIG.konamiSequence)).resolves.not.toThrow();
        expect(withSession).not.toHaveBeenCalled();
    });

    it('is flood-limited and silently ignores input once the limit is hit', async () => {
        const { socket, handlers } = makeSocket();
        sessionTracker.set('sid-1', { socketIds: new Set(['sock-1']), lastSeen: Date.now() } as SessionTrackerEntry);
        floodConsumeMock.mockReturnValue({ allowed: false, retryAfterMs: 1000 });
        registerCheatHandler(io, socket);

        await sendSequence(handlers, CHEAT_CONFIG.konamiSequence);

        expect(sessionTracker.get('sid-1')!.inputBuffer ?? []).toEqual([]);
        expect(withSession).not.toHaveBeenCalled();
    });

    it('ignores a malformed payload', async () => {
        const { socket, handlers } = makeSocket();
        sessionTracker.set('sid-1', { socketIds: new Set(['sock-1']), lastSeen: Date.now() } as SessionTrackerEntry);
        registerCheatHandler(io, socket);

        await expect(handlers['input']({ key: '' })).resolves.not.toThrow();
        expect(withSession).not.toHaveBeenCalled();
    });
});
