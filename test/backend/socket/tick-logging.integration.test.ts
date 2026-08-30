import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import type { Server as SocketIOServer } from 'socket.io';

/**
 * Regression tests locking in the exact `[TICK:<sid>] <Zone> | HP: ... (<status>)` log format
 * ported from the old game's socket.service.ts — see tick.ts's logTickResult. Deliberately does
 * NOT mock @/service/player.service, @/socket/session, or @/socket/emitter: the status text
 * depends on real getPlayerStats/processTick/processEffectExpiry behavior, not a stubbed one.
 * Only the session store/lock (so we control the "database") and the repository are mocked.
 */

vi.mock('@/util/lock.util', () => ({
    acquireSessionLock: vi.fn(),
}));

vi.mock('@/util/session-store.util', () => ({
    getSessionData: vi.fn(),
    setSessionData: vi.fn(),
}));

vi.mock('@/repository/statistics.repository', () => ({
    statisticsRepository: { increment: vi.fn().mockResolvedValue(undefined) },
}));

import { acquireSessionLock } from '@/util/lock.util';
import { getSessionData, setSessionData } from '@/util/session-store.util';
import { processSessionTick } from '@/socket/tick';
import { sessionTracker } from '@/socket/emitter';
import { logger } from '@/config/logger.config';

describe('tick logging format (integration — real player.service/session wiring)', () => {
    const SESSION_ID = 'sid-tick-log-1';
    let session: Record<string, any>;
    let io: SocketIOServer;
    let debugSpy: ReturnType<typeof vi.spyOn>;

    beforeEach(() => {
        vi.clearAllMocks();
        vi.useFakeTimers();
        sessionTracker.clear();
        sessionTracker.set(SESSION_ID, { socketIds: new Set(), lastSeen: Date.now() });

        session = {
            cookie: {},
            name: 'Hero',
            raceId: 0, // Human — startHealth 100, regen 1
            health: 50,
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

        io = { sockets: { sockets: { get: () => undefined } } } as unknown as SocketIOServer;
        debugSpy = vi.spyOn(logger, 'debug');
    });

    afterEach(() => {
        vi.useRealTimers();
        debugSpy.mockRestore();
    });

    function lastTickLine(): string {
        const call = debugSpy.mock.calls.find((c: unknown[]) => typeof c[0] === 'string' && c[0].includes('[TICK:'));
        expect(call).toBeDefined();
        return call![0] as string;
    }

    it('logs "+N HPR" and the old -> new/max HP display on a regen tick', async () => {
        await processSessionTick(io, sessionTracker.get(SESSION_ID)!, SESSION_ID, { applyRegen: true });

        const line = lastTickLine();
        expect(line).toContain('Resting | HP: 50 -> 51/100 (+1 HPR)');
    });

    it('logs "Full" once at max health with nothing else to report', async () => {
        session.health = 100;
        await processSessionTick(io, sessionTracker.get(SESSION_ID)!, SESSION_ID, { applyRegen: true });

        const line = lastTickLine();
        expect(line).toContain('Resting | HP: 100/100 (Full)');
    });

    it('logs "Paused" while in combat, even below max health', async () => {
        session.currentScreen = 'battle';
        session.effects = [{ id: 'combat', type: 'aura', emoji: '⚔️', label: 'In Combat', modifiers: [] }];

        await processSessionTick(io, sessionTracker.get(SESSION_ID)!, SESSION_ID, { applyRegen: true });

        const line = lastTickLine();
        expect(line).toContain('In Combat | HP: 50/100 (Paused)');
        expect(session.health).toBe(50); // never regenerated
    });

    it('logs "0 HPR" for a wounded resting player whose total regen is zero (Orc, no regen armor)', async () => {
        // Distinct from "Paused" (combat/death block an otherwise-working regen) and from "Idle"
        // (regen works, there is simply nothing to heal): here the player is out of combat, alive,
        // and below max HP, yet has literally no regeneration to apply.
        session.raceId = 1; // Orc — startHealth 150, regen 0
        session.health = 50; // wounded, and nothing can heal it

        await processSessionTick(io, sessionTracker.get(SESSION_ID)!, SESSION_ID, { applyRegen: true });

        const line = lastTickLine();
        expect(line).toContain('Resting | HP: 50/150 (0 HPR)');
        expect(session.health).toBe(50);
        expect(setSessionData).not.toHaveBeenCalled(); // nothing changed, nothing to persist
    });

    it('logs the "Dead" zone for a dead player, with regen reported as paused', async () => {
        session.dead = true;
        session.health = 0;
        session.currentScreen = 'death';

        await processSessionTick(io, sessionTracker.get(SESSION_ID)!, SESSION_ID, { applyRegen: true });

        const line = lastTickLine();
        expect(line).toContain('Dead | HP: 0/100 (Paused)');
    });

    it('logs a bare "| <Type> Expired" clause on a negative HP diff with no expiring effect to name', async () => {
        // Health sitting above the base max with no buff to blame for it (a stale value carried
        // in the session): the expiry sweep's clamp drives hpDiff negative while `expiring` is
        // empty, so the type falls back to the generic "Effect" and no ": <label>" suffix is added.
        session.health = 130;

        await processSessionTick(io, sessionTracker.get(SESSION_ID)!, SESSION_ID, { applyRegen: true });

        const line = lastTickLine();
        expect(line).toContain('HP: 130 -> 100/100 (-30 HP | Effect Expired)');
        expect(session.health).toBe(100);
    });

    it('logs "<Type> Expired: <label>" when a timed buff expires with no HP change', async () => {
        session.health = 100; // at max, so no maxHealth-clamp HP diff either
        session.effects.push({
            id: 'test_buff', type: 'buff', emoji: '💪', label: 'Test Buff',
            modifiers: [{ type: 'crit', value: 5 }],
            expiresAt: Date.now() - 1000, // already expired
        });

        await processSessionTick(io, sessionTracker.get(SESSION_ID)!, SESSION_ID, { applyRegen: true });

        const line = lastTickLine();
        expect(line).toContain('HP: 100/100 (Buff Expired: Test Buff)');
        expect(session.effects.some((e: any) => e.id === 'test_buff')).toBe(false); // actually removed
    });

    // Regression: the OLD game's format always includes "| <Type> Expired" on a negative HP
    // diff, with the ": <label>" suffix only conditional on there being one — a rewrite bug had
    // this backwards (omitting the whole "| ... Expired" clause whenever no label was present).
    it('includes "| <Type> Expired: <label>" on a negative HP diff (a maxHealth buff expiring and clamping current HP down)', async () => {
        // A +50 maxHealth buff already expired: player was at 130 HP (within the buffed 150 max)
        // — once processEffectExpiry drops the buff, the base max (100) clamps health down to
        // it, producing hpDiff = 100 - 130 = -30.
        session.health = 130;
        session.effects.push({
            id: 'temp_max_hp', type: 'buff', emoji: '❤️', label: 'Fading Vigor',
            modifiers: [{ type: 'maxHealth', value: 50 }],
            expiresAt: Date.now() - 1000,
        });

        await processSessionTick(io, sessionTracker.get(SESSION_ID)!, SESSION_ID, { applyRegen: true });

        const line = lastTickLine();
        expect(line).toContain('HP: 130 -> 100/100 (-30 HP | Buff Expired: Fading Vigor)');
        expect(session.health).toBe(100);
    });

    it('still logs (matching the old game: every tick firing logs, changed or not) but does not persist/emit for a truly idle tick', async () => {
        session.health = 100; // Full — a real no-op tick, nothing to regen or expire

        await processSessionTick(io, sessionTracker.get(SESSION_ID)!, SESSION_ID, { applyRegen: true });

        expect(lastTickLine()).toContain('(Full)');
        expect(setSessionData).not.toHaveBeenCalled();
    });

    // Regression: a pure zone flip (nothing else changed) must still persist/broadcast — but
    // must NOT be mislabeled "Effect Expired" in the log, since the old game's tick status never
    // had any concept of zone at all (zone lived entirely outside the tick, in
    // zone.middleware.ts). A prior version of this rewrite folded zoneChanged into the same
    // `changed` flag used for both the persist decision AND the log status, which would have
    // wrongly printed "Effect Expired" here.
    it('persists/emits a pure zone-only change (persisted aura stale relative to currentScreen) without mislabeling it "Effect Expired" in the log', async () => {
        // Persisted aura says combat with no countdown, but currentScreen says home — withSession's
        // automatic pre-mutation syncZoneAuras call reads that as "just left a combat zone" and
        // starts the disengage countdown before the tick body runs.
        session.currentScreen = 'home';
        session.effects = [{ id: 'combat', type: 'aura', emoji: '⚔️', label: 'In Combat', modifiers: [] }];
        session.health = 100; // Full — isolates the zone flip as the ONLY thing that changed

        await processSessionTick(io, sessionTracker.get(SESSION_ID)!, SESSION_ID, { applyRegen: true });

        const line = lastTickLine();
        expect(line).toContain('(Full)');
        expect(line).not.toContain('Effect Expired');
        expect(session.effects.map((e: any) => e.id)).toEqual(['combat']);
        expect(setSessionData).toHaveBeenCalled(); // the zone flip alone still persisted
    });

    // The same guarantee one step later: the countdown elapsing is also a pure zone change, and
    // must not be logged as an expiring effect either — the pre-mutation sync has already swapped
    // the aura by the time the tick body captures what is expiring.
    it('persists/emits the disengage countdown elapsing into resting, still without saying "Effect Expired"', async () => {
        session.currentScreen = 'home';
        session.combatUntil = Date.now() - 1;
        session.effects = [{ id: 'combat', type: 'aura', emoji: '⚔️', label: 'In Combat', modifiers: [], expiresAt: Date.now() - 1 }];
        session.health = 100;

        await processSessionTick(io, sessionTracker.get(SESSION_ID)!, SESSION_ID, { applyRegen: true });

        const line = lastTickLine();
        expect(line).toContain('(Full)');
        expect(line).not.toContain('Effect Expired');
        expect(line).not.toContain('In Combat');
        expect(session.effects.map((e: any) => e.id)).toEqual(['resting']);
        expect(setSessionData).toHaveBeenCalled();
    });
});
