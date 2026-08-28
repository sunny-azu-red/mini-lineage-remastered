import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import type { Socket, Server as SocketIOServer } from 'socket.io';
import { TICK_CONFIG } from '@/constant/game.constant';
import type { BattleResult } from '@/interface';

/**
 * Genuinely end-to-end regression test for the fix described in player.service.ts's
 * syncZoneAuras (linger-driven combat aura gets a real `expiresAt`) combined with the
 * registry.ts wiring fix (a successful mutation reschedules exact expiry timers via
 * src/socket/tick.ts's refreshExpiryTimers, not just the periodic tick/reconnect).
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
import { trackSocket, sessionTracker } from '@/socket/emitter';

function makeBattleResult(overrides: Partial<BattleResult> = {}): BattleResult {
    return {
        enemiesKilled: 1,
        hpLost: 5,
        damageBlocked: 0,
        xpGained: 1,
        adenaGained: 1,
        isCritical: false,
        isLevelUp: false,
        ...overrides,
    };
}

describe('combat aura exact-expiry wiring (integration)', () => {
    const SESSION_ID = 'sid-integration-1';
    let session: Record<string, any>;
    let ack: ReturnType<typeof vi.fn>;
    let fightHandler: (...args: unknown[]) => Promise<void>;
    let sock1Emit: ReturnType<typeof vi.fn>;

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
            effects: [{ id: 'resting', type: 'aura', emoji: '💤', label: 'Resting', modifiers: [] }],
            revision: 1,
        };

        vi.mocked(acquireSessionLock).mockResolvedValue(() => {});
        vi.mocked(getSessionData).mockImplementation(async () => session);
        vi.mocked(setSessionData).mockImplementation(async () => undefined);
        vi.mocked(simulateBattle).mockReturnValue(makeBattleResult());

        const io = {
            sockets: { sockets: { get: (id: string) => (id === 'sock-1' ? { emit: sock1Emit } : undefined) } },
        } as unknown as SocketIOServer;
        sock1Emit = vi.fn();

        const handlers: Record<string, (...args: unknown[]) => Promise<void>> = {};
        const socket = {
            on: vi.fn((event: string, cb: (...args: unknown[]) => Promise<void>) => { handlers[event] = cb; }),
            request: { session: { id: SESSION_ID } },
            id: 'sock-1',
        } as unknown as Socket;

        trackSocket(io, SESSION_ID, 'sock-1');
        registerBattleHandlers(io, socket);
        fightHandler = handlers['battle:fight'];

        ack = vi.fn();
    });

    afterEach(() => {
        vi.useRealTimers();
    });

    it('schedules an exact "combat" expiry timer on battle:fight and flips to resting at exactly combatLingerMs later, with no periodic tick involved', async () => {
        const t0 = Date.now();

        await fightHandler(ack);

        // The fight succeeded and set an exact expiresAt on the combat aura.
        expect(ack).toHaveBeenCalledWith(expect.objectContaining({ ok: true }));
        const combatAfterFight = session.effects.find((e: any) => e.id === 'combat');
        expect(combatAfterFight).toBeDefined();
        expect(combatAfterFight.expiresAt).toBe(t0 + TICK_CONFIG.combatLingerMs);

        // registry.ts's post-mutation refreshExpiryTimers() call (Fix 2) must have scheduled
        // a real timer for it immediately — not left it to the next periodic tick.
        const tracker = sessionTracker.get(SESSION_ID);
        expect(tracker?.expiryTimers?.has('combat')).toBe(true);

        // Advance to 1ms before the exact expiry instant (plus syncExpiryTimers' own +25ms
        // scheduling grace) — the aura must still read combat, proving this isn't riding on
        // TICK_CONFIG.intervalMs (5s) cadence.
        await vi.advanceTimersByTimeAsync(TICK_CONFIG.combatLingerMs + 24);
        expect(session.effects.some((e: any) => e.id === 'combat')).toBe(true);
        expect(session.effects.some((e: any) => e.id === 'resting')).toBe(false);

        // Cross the exact expiry instant: the scheduled setTimeout (not any interval/tick
        // loop — none was ever started in this test) fires, re-processes the session with
        // { applyRegen: false }, and syncZoneAuras flips combat -> resting.
        await vi.advanceTimersByTimeAsync(2);

        expect(session.effects.some((e: any) => e.id === 'combat')).toBe(false);
        expect(session.effects.some((e: any) => e.id === 'resting')).toBe(true);

        // The flip was persisted and pushed to the socket, exactly like a timed buff expiring.
        expect(setSessionData).toHaveBeenCalledWith(SESSION_ID, session);
        expect(sock1Emit).toHaveBeenCalledWith('state:update', expect.objectContaining({
            effects: expect.arrayContaining([expect.objectContaining({ id: 'resting' })]),
        }));

        // The now-inactive 'combat' timer entry was cleaned up (recomputed as part of the
        // expiry-triggered tick's own refreshExpiryTimers call).
        expect(tracker?.expiryTimers?.has('combat')).toBe(false);
    });

    it('does not schedule any expiry timer for an ambush-driven combat aura (no fixed end time)', async () => {
        session.ambushed = false;
        const mathService = await import('@/service/math.service');
        vi.mocked(mathService.calculateAmbushChance).mockReturnValue(true);

        await fightHandler(ack);

        const combatAfterFight = session.effects.find((e: any) => e.id === 'combat');
        expect(combatAfterFight).toBeDefined();
        expect(combatAfterFight.expiresAt).toBeUndefined();

        const tracker = sessionTracker.get(SESSION_ID);
        expect(tracker?.expiryTimers?.has('combat')).toBe(false);
    });
});
