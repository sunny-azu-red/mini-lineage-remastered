import { describe, it, expect, vi, beforeEach } from 'vitest';
import type { Socket, Server as SocketIOServer } from 'socket.io';

vi.mock('@/socket/registry', () => ({ registerEvent: vi.fn() }));
vi.mock('@/repository/statistics.repository', () => ({
    statisticsRepository: { increment: vi.fn().mockResolvedValue(undefined) },
}));

import { registerEvent } from '@/socket/registry';
import { registerGameHandlers } from '@/socket/handler/game.handler';
import { requireNotStarted, requireDead } from '@/socket/guard';
import type { SessionContext } from '@/socket/session';
import type { PlayerState } from '@/interface';

function getDef(event: string) {
    const call = vi.mocked(registerEvent).mock.calls.find(c => (c[2] as any).event === event);
    if (!call)
        throw new Error(`${event} not registered`);

    return call[2] as any;
}

function makeCtx(player: Partial<PlayerState> = {}): SessionContext {
    return { sessionId: 'sid-1', session: {}, player: player as PlayerState, zoneChanged: false, expiry: { removed: [], healthBefore: undefined, changed: false } };
}

describe('game.handler', () => {
    const io = {} as SocketIOServer;
    const socket = {} as Socket;

    beforeEach(() => {
        vi.clearAllMocks();
        registerGameHandlers(io, socket);
    });

    describe('game:start', () => {
        it('is mutating and guarded by requireNotStarted', () => {
            const def = getDef('game:start');
            expect(def.mode).toBe('mutate');
            expect(def.guards).toEqual([requireNotStarted]);
        });

        it('initializes the player and returns a MutationResult carrying the start flash', () => {
            const ctx = makeCtx();
            const result = getDef('game:start').handler(ctx, { raceId: 0, name: 'Hero' });

            expect(ctx.player.name).toBe('Hero');
            expect(ctx.player.raceId).toBe(0);
            expect(result.player.started).toBe(true);
            expect(result.player.name).toBe('Hero');
            expect(result.flash).toMatchObject({ type: 'info', sound: 'start' });
        });
    });

    describe('game:restart', () => {
        // Restarting destroys a character, so only a dead one may be destroyed. The old app got
        // this from cheatMiddleware gating /restart; here it is a guard on the event itself, the
        // one place a raw socket client cannot route around.
        it('is guarded by requireDead — a living character can never be wiped', () => {
            expect(getDef('game:restart').guards).toEqual([requireDead]);
        });

        it('resets the player in place (not session.destroy) and returns a fresh hydrate payload', () => {
            const ctx = makeCtx({
                name: 'Old', raceId: 1, health: 10, adena: 5, experience: 100,
                weaponId: 1, armorId: 1, dead: true,
            });

            const result = getDef('game:restart').handler(ctx);

            expect(ctx.player.name).toBeUndefined();
            expect(ctx.player.raceId).toBeUndefined();
            expect(result.hydrate.player.started).toBe(false);
            expect(result.hydrate.catalog.races.length).toBeGreaterThan(0);
        });
    });
});
