import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import type { Socket, Server as SocketIOServer } from 'socket.io';
import { TICK_CONFIG } from '@/constant/game.constant';
import type { BattleResult } from '@/interface';

/**
 * Genuinely end-to-end regression test for the location-based zone system (player.service.ts's
 * syncZoneAuras, which classifies combat/resting purely from `player.currentScreen` — a direct
 * port of the old game's URL-path-based zone.middleware.ts, with zero timers involved) combined
 * with the registry.ts wiring (a successful mutation broadcasts immediately, no tick delay).
 *
 * Deliberately does NOT mock @/socket/registry, @/socket/session, @/socket/emitter,
 * @/socket/tick, or @/service/player.service — those are exactly the modules whose
 * real wiring together is under test. Only the session store/lock (so we control the
 * "database") and the battle RNG (so the outcome is deterministic) are mocked.
 */

vi.mock('@/util/lock.util', () => ({
    acquireSessionLock: vi.fn(),
}));

vi.mock('@/util/session-store.util', () => ({
    getSessionData: vi.fn(),
    setSessionData: vi.fn(),
}));

vi.mock('@/service/battle.service', () => ({
    simulateBattle: vi.fn(),
}));

vi.mock('@/repository/statistics.repository', () => ({
    statisticsRepository: { increment: vi.fn().mockResolvedValue(undefined) },
}));

vi.mock('@/service/math.service', async (importOriginal) => {
    const actual = await importOriginal<typeof import('@/service/math.service')>();
    return { ...actual, calculateAmbushChance: vi.fn(() => false) };
});

import { acquireSessionLock } from '@/util/lock.util';
import { getSessionData, setSessionData } from '@/util/session-store.util';
import { simulateBattle } from '@/service/battle.service';
import { registerBattleHandlers } from '@/socket/handler/battle.handler';
import { registerPlayerHandlers } from '@/socket/handler/player.handler';
import { trackSocket, sessionTracker } from '@/socket/emitter';
import { processSessionTick } from '@/socket/tick';
import { makeBattleResult } from '../factories';

describe('location-based zone sync (integration)', () => {
    const SESSION_ID = 'sid-integration-1';
    let session: Record<string, any>;
    let ack: ReturnType<typeof vi.fn>;
    let fightHandler: (...args: unknown[]) => Promise<void>;
    let screenHandler: (...args: unknown[]) => Promise<void>;
    let sock1Emit: ReturnType<typeof vi.fn>;
    let io: SocketIOServer;

    beforeEach(() => {
        vi.clearAllMocks();
        vi.useFakeTimers();
        sessionTracker.clear();

        session = {
            cookie: {},
            name: 'Hero',
            raceId: 0,
            health: 100,
            adena: 100,
            experience: 0,
            weaponId: 0,
            armorId: 0,
            dead: false,
            ambushed: false,
            currentScreen: 'home',
            effects: [{ id: 'resting', type: 'aura', emoji: '💤', label: 'Resting', modifiers: [] }],
            revision: 1,
        };

        vi.mocked(acquireSessionLock).mockResolvedValue(() => {});
        vi.mocked(getSessionData).mockImplementation(async () => session);
        vi.mocked(setSessionData).mockImplementation(async () => undefined);
        vi.mocked(simulateBattle).mockReturnValue(makeBattleResult());

        sock1Emit = vi.fn();
        io = {
            sockets: { sockets: { get: (id: string) => (id === 'sock-1' ? { emit: sock1Emit } : undefined) } },
        } as unknown as SocketIOServer;

        const handlers: Record<string, (...args: unknown[]) => Promise<void>> = {};
        const socket = {
            on: vi.fn((event: string, cb: (...args: unknown[]) => Promise<void>) => { handlers[event] = cb; }),
            request: { session: { id: SESSION_ID } },
            id: 'sock-1',
        } as unknown as Socket;

        trackSocket(io, SESSION_ID, 'sock-1');
        registerBattleHandlers(io, socket);
        registerPlayerHandlers(io, socket);
        fightHandler = handlers['battle:fight'];
        screenHandler = handlers['player:screen'];

        ack = vi.fn();
    });

    afterEach(() => {
        vi.useRealTimers();
    });

    it('fighting sets currentScreen to "battle" and a combat aura with no expiry, regardless of what screen was last reported', async () => {
        await fightHandler(ack);
        expect(ack).toHaveBeenCalledWith(expect.objectContaining({ ok: true }));

        expect(session.currentScreen).toBe('battle');
        const combat = session.effects.find((e: any) => e.id === 'combat');
        expect(combat).toBeDefined();
        expect(combat.expiresAt).toBeUndefined();
    });

    it('reporting a resting screen via player:screen flips the aura to resting instantly — no tick, no timer, no periodic loop involved', async () => {
        await fightHandler(ack);
        expect(session.effects.some((e: any) => e.id === 'combat')).toBe(true);

        const screenAck = vi.fn();
        await screenHandler({ screen: 'home' }, screenAck);
        expect(screenAck).toHaveBeenCalledWith(expect.objectContaining({ ok: true }));

        expect(session.currentScreen).toBe('home');
        expect(session.effects.some((e: any) => e.id === 'combat')).toBe(false);
        expect(session.effects.some((e: any) => e.id === 'resting')).toBe(true);

        // Broadcast happened as part of THIS mutation's own ack processing — no advancing of
        // fake timers was needed anywhere in this test to observe the flip.
        expect(setSessionData).toHaveBeenCalledWith(SESSION_ID, session);
    });

    it('never lets regen resume while currentScreen stays "battle", no matter how much time passes — the exact exploit the old lastFightAt-based heuristic was vulnerable to', async () => {
        session.health = 10; // well below max, so regen WOULD fire here if it were unblocked

        await fightHandler(ack);
        expect(session.ambushed).toBe(false); // a regular (non-ambush) battle
        const healthAfterFight = session.health;

        // Advance well past several periodic ticks — proving regen stays blocked purely because
        // currentScreen is still 'battle', regardless of how much idle time passes.
        for (let i = 0; i < 5; i++) {
            await vi.advanceTimersByTimeAsync(TICK_CONFIG.intervalMs);
            await processSessionTick(io, sessionTracker.get(SESSION_ID)!, SESSION_ID, { applyRegen: true });
        }

        expect(session.health).toBe(healthAfterFight); // never regenerated
        expect(session.effects.some((e: any) => e.id === 'combat')).toBe(true);
        expect(session.effects.find((e: any) => e.id === 'combat').expiresAt).toBeUndefined();
    });

    it('never schedules any expiry timer for a zone aura — combat/resting never carry expiresAt, unlike a real timed buff', async () => {
        await fightHandler(ack);

        const tracker = sessionTracker.get(SESSION_ID);
        expect(tracker?.expiryTimers?.has('combat')).toBe(false);
        expect(tracker?.expiryTimers?.has('resting')).toBe(false);
    });

    it('ambushed unconditionally forces combat even if a raw client reports a resting screen — the safety net the old game\'s naive path-trust model lacked', async () => {
        const mathService = await import('@/service/math.service');
        vi.mocked(mathService.calculateAmbushChance).mockReturnValue(true);
        session.health = 10;

        await fightHandler(ack);
        expect(session.ambushed).toBe(true);
        const healthAfterFight = session.health;

        // A dishonest client claims to have gone Home while still ambushed.
        const screenAck = vi.fn();
        await screenHandler({ screen: 'home' }, screenAck);

        expect(session.effects.some((e: any) => e.id === 'combat')).toBe(true);
        expect(session.effects.some((e: any) => e.id === 'resting')).toBe(false);

        for (let i = 0; i < 5; i++) {
            await vi.advanceTimersByTimeAsync(TICK_CONFIG.intervalMs);
            await processSessionTick(io, sessionTracker.get(SESSION_ID)!, SESSION_ID, { applyRegen: true });
        }

        expect(session.health).toBe(healthAfterFight); // never regenerated
        expect(session.ambushed).toBe(true); // still unresolved — only an explicit fight changes this
    });
});
