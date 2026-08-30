import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import type { Socket, Server as SocketIOServer } from 'socket.io';
import { TICK_CONFIG, ZONE_CONFIG } from '@/constant/game.constant';
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

    it('reporting a resting screen via player:screen does NOT rest instantly — it starts a combatLingerMs disengage countdown', async () => {
        await fightHandler(ack);
        expect(session.effects.some((e: any) => e.id === 'combat')).toBe(true);

        const screenAck = vi.fn();
        await screenHandler({ screen: 'home' }, screenAck);
        expect(screenAck).toHaveBeenCalledWith(expect.objectContaining({ ok: true }));

        expect(session.currentScreen).toBe('home');
        expect(session.effects.some((e: any) => e.id === 'resting')).toBe(false);

        const combat = session.effects.find((e: any) => e.id === 'combat');
        expect(combat).toBeDefined();
        expect(combat.expiresAt).toBe(Date.now() + ZONE_CONFIG.combatLingerMs);

        // The countdown starting is itself the change — persisted from THIS mutation's own ack
        // processing, with no fake timers advanced to observe it.
        expect(setSessionData).toHaveBeenCalledWith(SESSION_ID, session);
    });

    it('flips to resting once the countdown elapses, driven by the aura\'s own exact timer rather than the tick loop', async () => {
        await fightHandler(ack);
        await screenHandler({ screen: 'home' }, vi.fn());

        // One millisecond short: still disengaging.
        await vi.advanceTimersByTimeAsync(ZONE_CONFIG.combatLingerMs - 1);
        expect(session.effects.some((e: any) => e.id === 'combat')).toBe(true);
        expect(session.effects.some((e: any) => e.id === 'resting')).toBe(false);

        // syncExpiryTimers scheduled the wake-up at expiry + 25ms. Nothing here advances by a
        // whole TICK_CONFIG.intervalMs, so the periodic loop cannot be what resolved this.
        await vi.advanceTimersByTimeAsync(30);

        expect(session.effects.some((e: any) => e.id === 'combat')).toBe(false);
        expect(session.effects.some((e: any) => e.id === 'resting')).toBe(true);
        expect(session.combatUntil).toBeUndefined();
    });

    it('keeps regen paused for the whole countdown, and resumes it only afterwards — the reported scenario end to end', async () => {
        session.health = 10; // well below max, so regen fires the moment it is allowed to

        await fightHandler(ack);
        await screenHandler({ screen: 'home' }, vi.fn());
        const healthOnLeaving = session.health;

        // A periodic tick lands mid-countdown: still in combat, so it must heal nothing. The
        // offset is deliberately NOT TICK_CONFIG.intervalMs — that happens to equal
        // combatLingerMs today, which would land exactly ON the deadline and prove nothing.
        await vi.advanceTimersByTimeAsync(ZONE_CONFIG.combatLingerMs - 2_000);
        await processSessionTick(io, sessionTracker.get(SESSION_ID)!, SESSION_ID, { applyRegen: true });
        expect(session.effects.some((e: any) => e.id === 'combat')).toBe(true);
        expect(session.health).toBe(healthOnLeaving);

        // Let the countdown elapse, then tick again.
        await vi.advanceTimersByTimeAsync(2_030);
        expect(session.effects.some((e: any) => e.id === 'resting')).toBe(true);

        await processSessionTick(io, sessionTracker.get(SESSION_ID)!, SESSION_ID, { applyRegen: true });
        expect(session.health).toBeGreaterThan(healthOnLeaving);
    });

    it('re-arms a fresh countdown on every exit, so bouncing Back and Forward never rests early', async () => {
        await fightHandler(ack);
        await screenHandler({ screen: 'home' }, vi.fn());
        const firstDeadline = session.combatUntil;

        // Browser Back onto /battle: standing in the zone again, so the countdown is cancelled.
        await vi.advanceTimersByTimeAsync(3_000);
        await screenHandler({ screen: 'battle' }, vi.fn());
        expect(session.combatUntil).toBeUndefined();
        expect(session.effects.find((e: any) => e.id === 'combat').expiresAt).toBeUndefined();
        expect(sessionTracker.get(SESSION_ID)?.expiryTimers?.has('combat')).toBe(false);

        // Forward to /home again: a full countdown, not the remainder of the first one.
        await screenHandler({ screen: 'home' }, vi.fn());
        expect(session.combatUntil).toBe(Date.now() + ZONE_CONFIG.combatLingerMs);
        expect(session.combatUntil).toBeGreaterThan(firstDeadline);
    });

    it('does not re-arm the countdown while already disengaging, so repeated syncs cannot extend it', async () => {
        await fightHandler(ack);
        await screenHandler({ screen: 'home' }, vi.fn());
        const deadline = session.combatUntil;

        await vi.advanceTimersByTimeAsync(2_000);
        await screenHandler({ screen: 'inn' }, vi.fn());   // resting zone -> resting zone
        await processSessionTick(io, sessionTracker.get(SESSION_ID)!, SESSION_ID, { applyRegen: true });

        expect(session.combatUntil).toBe(deadline);
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

    it('schedules no expiry timer while HELD in a combat zone — that combat is indefinite, unlike a real timed buff', async () => {
        await fightHandler(ack);

        const tracker = sessionTracker.get(SESSION_ID);
        expect(tracker?.expiryTimers?.has('combat')).toBe(false);
        expect(tracker?.expiryTimers?.has('resting')).toBe(false);
    });

    it('schedules one for the disengage countdown, and never for the resting aura', async () => {
        await fightHandler(ack);
        await screenHandler({ screen: 'home' }, vi.fn());

        const tracker = sessionTracker.get(SESSION_ID);
        expect(tracker?.expiryTimers?.has('combat')).toBe(true);
        expect(tracker?.expiryTimers?.has('resting')).toBe(false);

        await vi.advanceTimersByTimeAsync(ZONE_CONFIG.combatLingerMs + 30);
        expect(tracker?.expiryTimers?.has('combat')).toBe(false);
        expect(tracker?.expiryTimers?.has('resting')).toBe(false);
    });

    it('gives a reconnecting player who left the tab on /battle an untimed aura, and the countdown only once they move', async () => {
        // No fight this time: the session simply persisted mid-battleground.
        session.currentScreen = 'battle';
        session.effects = [{ id: 'combat', type: 'aura', emoji: '⚔️', label: 'In Combat', modifiers: [] }];

        await screenHandler({ screen: 'battle' }, vi.fn());
        expect(session.effects.find((e: any) => e.id === 'combat').expiresAt).toBeUndefined();

        await screenHandler({ screen: 'home' }, vi.fn());
        expect(session.effects.find((e: any) => e.id === 'combat').expiresAt).toBe(Date.now() + ZONE_CONFIG.combatLingerMs);
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
