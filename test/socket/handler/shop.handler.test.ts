import { describe, it, expect, vi, beforeEach } from 'vitest';
import type { Socket, Server as SocketIOServer } from 'socket.io';

vi.mock('@/socket/registry', () => ({ registerEvent: vi.fn() }));
vi.mock('@/repository/statistics.repository', () => ({
    statisticsRepository: { increment: vi.fn().mockResolvedValue(undefined) },
}));

import { registerEvent } from '@/socket/registry';
import { registerShopHandlers } from '@/socket/handler/shop.handler';
import { requireStarted, requireAlive } from '@/socket/guard';
import { shopLimiter } from '@/socket/rate-limit';
import { SocketError } from '@/socket/error';
import { WEAPONS, ARMORS, FOODS } from '@/constant/game.constant';
import type { SessionContext } from '@/socket/session';
import type { PlayerState } from '@/interface';

function getDef() {
    const call = vi.mocked(registerEvent).mock.calls.find(c => (c[2] as any).event === 'shop:purchase');
    if (!call)
        throw new Error('shop:purchase not registered');

    return call[2] as any;
}

function makePlayer(overrides: Partial<PlayerState> = {}): PlayerState {
    return {
        name: 'Hero', raceId: 0, health: 100, adena: 100_000, experience: 0,
        weaponId: 0, armorId: 0, ...overrides,
    } as PlayerState;
}

function makeCtx(player: PlayerState): SessionContext {
    return { sessionId: 'sid-1', session: {}, player, zoneChanged: false };
}

describe('shop.handler', () => {
    const io = {} as SocketIOServer;
    const socket = {} as Socket;

    beforeEach(() => {
        vi.clearAllMocks();
        registerShopHandlers(io, socket);
    });

    it('guards requireStarted/requireAlive and rate-limits with shopLimiter', () => {
        const def = getDef();
        expect(def.guards).toEqual([requireStarted, requireAlive]);
        expect(def.rateLimit).toBe(shopLimiter);
    });

    it('buys a weapon, updates weaponId, and flashes success with "buy" sound', () => {
        const ctx = makeCtx(makePlayer());
        const result = getDef().handler(ctx, { type: 'weapon', itemId: WEAPONS[1].id });

        expect(ctx.player.weaponId).toBe(WEAPONS[1].id);
        expect(result.flash).toMatchObject({ type: 'success', sound: 'buy' });
        expect(result.player.weapon?.id).toBe(WEAPONS[1].id);
    });

    it('buys armor, updates armorId, and flashes success with "buy" sound', () => {
        const ctx = makeCtx(makePlayer());
        const result = getDef().handler(ctx, { type: 'armor', itemId: ARMORS[1].id });

        expect(ctx.player.armorId).toBe(ARMORS[1].id);
        expect(result.flash).toMatchObject({ type: 'success', sound: 'buy' });
    });

    it('eats food and flashes success with "eat" sound', () => {
        const ctx = makeCtx(makePlayer({ health: 10 }));
        const result = getDef().handler(ctx, { type: 'food', itemId: FOODS[0].id });

        expect(result.flash).toMatchObject({ type: 'success', sound: 'eat' });
    });

    it('is an ok:true-shaped result (not a thrown error) when funds are insufficient (plan A11)', () => {
        const ctx = makeCtx(makePlayer({ adena: 0 }));
        const result = getDef().handler(ctx, { type: 'weapon', itemId: WEAPONS[1].id });

        expect(result.flash).toMatchObject({ type: 'danger' });
        expect(result.flash.sound).toBeUndefined();
        expect(ctx.player.weaponId).toBe(0); // unchanged
    });

    it('flashes danger when already wielding the selected weapon', () => {
        const ctx = makeCtx(makePlayer({ weaponId: WEAPONS[1].id }));
        const result = getDef().handler(ctx, { type: 'weapon', itemId: WEAPONS[1].id });

        expect(result.flash).toMatchObject({ type: 'danger' });
    });

    it('throws INVALID_PAYLOAD if purchaseItem cannot resolve the item at all', () => {
        const ctx = makeCtx(makePlayer());

        expect(() => getDef().handler(ctx, { type: 'weapon', itemId: 9_999 })).toThrow(SocketError);
        try {
            getDef().handler(ctx, { type: 'weapon', itemId: 9_999 });
            expect.unreachable();
        } catch (err) {
            expect((err as SocketError).code).toBe('INVALID_PAYLOAD');
        }
    });
});
