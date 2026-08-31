import { describe, it, expect, vi, beforeEach } from 'vitest';
import type { Socket, Server as SocketIOServer } from 'socket.io';

vi.mock('@/socket/registry', () => ({ registerEvent: vi.fn() }));
vi.mock('@/repository/statistics.repository', () => ({
    statisticsRepository: { increment: vi.fn().mockResolvedValue(undefined) },
}));

import { registerEvent } from '@/socket/registry';
import { registerPlayerHandlers } from '@/socket/handler/player.handler';
import { requireStarted, requireAlive } from '@/socket/guard';
import { statisticsRepository } from '@/repository/statistics.repository';
import type { SessionContext } from '@/socket/session';
import type { PlayerState } from '@/interface';

function getDef() {
    const call = vi.mocked(registerEvent).mock.calls.find(c => (c[2] as any).event === 'player:suicide');
    if (!call)
        throw new Error('player:suicide not registered');

    return call[2] as any;
}

function makeCtx(overrides: Partial<PlayerState> = {}): SessionContext {
    const player = {
        name: 'Hero', raceId: 0, health: 50, adena: 10, experience: 0,
        weaponId: 0, armorId: 0, ...overrides,
    } as PlayerState;

    return { sessionId: 'sid-1', session: {}, player, zoneChanged: false, expiry: { removed: [], healthBefore: undefined, changed: false } };
}

describe('player.handler', () => {
    const io = {} as SocketIOServer;
    const socket = {} as Socket;

    beforeEach(() => {
        vi.clearAllMocks();
        registerPlayerHandlers(io, socket);
    });

    it('guards requireStarted/requireAlive and has no dedicated rate limiter', () => {
        const def = getDef();
        expect(def.guards).toEqual([requireStarted, requireAlive]);
        expect(def.rateLimit).toBeUndefined();
    });

    it('commits suicide, marks coward, increments the suicide stat, and returns a null-flash MutationResult', () => {
        const ctx = makeCtx();
        const result = getDef().handler(ctx);

        expect(ctx.player.dead).toBe(true);
        expect(ctx.player.coward).toBe(true);
        expect(ctx.player.deathReason).toBeTruthy();
        expect(statisticsRepository.increment).toHaveBeenCalledWith('total_players_suicided');
        expect(result).toEqual({ player: result.player, flash: null });
        expect(result.player.dead).toBe(true);
    });

    // The client now moves to the death screen in the same atomic store update that applies this
    // ack, so it never sends a follow-up player:screen. The handler stamps its own destination
    // instead — the same pattern game:start and battle:fight already use.
    it('stamps currentScreen as death so the session never keeps a stale location', () => {
        const ctx = makeCtx({ currentScreen: 'suicide' });

        getDef().handler(ctx);

        expect(ctx.player.currentScreen).toBe('death');
        expect(ctx.player.dead).toBe(true);
    });
});
