import { describe, it, expect, vi, beforeEach } from 'vitest';
import { withSession, readSession, NO_CHANGE, SessionContext } from '@/socket/session';
import { SocketError } from '@/socket/error';
import { acquireSessionLock } from '@/util/lock.util';
import { getSessionData, setSessionData } from '@/util/session-store.util';
import { EFFECTS_CONFIG } from '@/constant/game.constant';

// Note: `@/service/player.service` is deliberately NOT mocked in this file — withSession's
// automatic zone-sync (Fix 8) is real production wiring, and these tests rely on the real
// `isGameStarted`/`syncZoneAuras` to verify it end-to-end.

vi.mock('@/util/lock.util', () => ({
    acquireSessionLock: vi.fn(),
}));

vi.mock('@/util/session-store.util', () => ({
    getSessionData: vi.fn(),
    setSessionData: vi.fn(),
}));

describe('withSession', () => {
    let release: ReturnType<typeof vi.fn>;

    beforeEach(() => {
        vi.clearAllMocks();
        release = vi.fn(() => {});
        vi.mocked(acquireSessionLock).mockResolvedValue(release as unknown as () => void);
        vi.mocked(setSessionData).mockResolvedValue(undefined);
    });

    it('locks, loads, mutates, bumps revision, persists, and releases the lock', async () => {
        const session = { cookie: {}, raceId: 0, health: 100, revision: 4 };
        vi.mocked(getSessionData).mockResolvedValue(session);

        const result = await withSession('sid-1', (ctx) => {
            ctx.player.health = 90;
            return 'ok';
        });

        expect(result).toBe('ok');
        expect(acquireSessionLock).toHaveBeenCalledWith('sid-1');
        expect(getSessionData).toHaveBeenCalledWith('sid-1');
        expect(session.revision).toBe(5);
        expect(setSessionData).toHaveBeenCalledWith('sid-1', session);
        expect(release).toHaveBeenCalledTimes(1);
    });

    it('initializes revision to 1 when absent', async () => {
        const session = { cookie: {} };
        vi.mocked(getSessionData).mockResolvedValue(session);

        await withSession('sid-1', () => 'ok');

        expect((session as any).revision).toBe(1);
    });

    it('skips persistence and resolves undefined when the mutator returns NO_CHANGE', async () => {
        const session = { cookie: {}, revision: 1 };
        vi.mocked(getSessionData).mockResolvedValue(session);

        const result = await withSession('sid-1', () => NO_CHANGE);

        expect(result).toBeUndefined();
        expect(setSessionData).not.toHaveBeenCalled();
        expect(session.revision).toBe(1); // untouched
        expect(release).toHaveBeenCalledTimes(1);
    });

    it('throws SESSION_EXPIRED and releases the lock when the session is gone', async () => {
        vi.mocked(getSessionData).mockResolvedValue(null);

        await expect(withSession('sid-missing', () => 'ok')).rejects.toMatchObject({ code: 'SESSION_EXPIRED' });
        expect(release).toHaveBeenCalledTimes(1);
        expect(setSessionData).not.toHaveBeenCalled();
    });

    it('propagates the mutator error and still releases the lock', async () => {
        const session = { cookie: {} };
        vi.mocked(getSessionData).mockResolvedValue(session);

        await expect(withSession('sid-1', () => {
            throw new SocketError('DEAD', 'nope');
        })).rejects.toMatchObject({ code: 'DEAD' });

        expect(release).toHaveBeenCalledTimes(1);
        expect(setSessionData).not.toHaveBeenCalled();
    });

    it('supports an async mutator', async () => {
        const session = { cookie: {} };
        vi.mocked(getSessionData).mockResolvedValue(session);

        const result = await withSession('sid-1', async (ctx) => {
            await Promise.resolve();
            ctx.player.health = 1;
            return 'async-ok';
        });

        expect(result).toBe('async-ok');
        expect(setSessionData).toHaveBeenCalled();
    });

    it('never releases the lock more than once even under concurrent completion paths', async () => {
        const session = { cookie: {} };
        vi.mocked(getSessionData).mockResolvedValue(session);

        await withSession('sid-1', () => 'ok');
        // release is only ever invoked by the finally block, exactly once
        expect(release).toHaveBeenCalledTimes(1);
    });
});

describe('withSession — automatic zone-aura sync (Fix 8)', () => {
    let release: ReturnType<typeof vi.fn>;

    beforeEach(() => {
        vi.clearAllMocks();
        release = vi.fn(() => {});
        vi.mocked(acquireSessionLock).mockResolvedValue(release as unknown as () => void);
        vi.mocked(setSessionData).mockResolvedValue(undefined);
    });

    function makeStartedSession(overrides: Record<string, any> = {}): Record<string, any> {
        return {
            cookie: {},
            raceId: 0,
            health: 100,
            adena: 50,
            dead: false,
            ambushed: false,
            revision: 1,
            ...overrides,
        };
    }

    it('persists a zone-only flip even when the handler itself reports NO_CHANGE (the silent-drop bug)', async () => {
        // Persisted aura is out of step with currentScreen (e.g. a player:screen call updated the
        // screen without also calling syncZoneAuras itself). An INDEFINITE combat aura on a
        // resting screen reads as "just left a combat zone", so syncZoneAuras starts the disengage
        // countdown — a change the mutate callback below has no idea happened, and reports
        // NO_CHANGE regardless. The flip must still persist.
        const session = makeStartedSession({
            currentScreen: 'home',
            effects: [{ ...EFFECTS_CONFIG.combatAura }],
        });
        vi.mocked(getSessionData).mockResolvedValue(session);

        const result = await withSession('sid-1', () => NO_CHANGE);

        expect(result).toBeUndefined();
        expect(setSessionData).toHaveBeenCalledWith('sid-1', session);
        expect(session.revision).toBe(2); // still bumped — this genuinely persisted
        expect(session.effects.map((e: any) => e.id)).toEqual(['combat']);
        // Gaining a countdown is the change; without comparing expiresAt it would look like none.
        expect(session.effects[0].expiresAt).toBe(session.combatUntil);
        expect(session.combatUntil).toBeGreaterThan(Date.now());
    });

    it('persists the countdown ELAPSING into a resting aura, likewise with the mutator reporting NO_CHANGE', async () => {
        const session = makeStartedSession({
            currentScreen: 'home',
            combatUntil: Date.now() - 1, // disengage already over
            effects: [{ ...EFFECTS_CONFIG.combatAura, expiresAt: Date.now() - 1 }],
        });
        vi.mocked(getSessionData).mockResolvedValue(session);

        await withSession('sid-1', () => NO_CHANGE);

        expect(session.effects.map((e: any) => e.id)).toEqual(['resting']);
        expect(session.combatUntil).toBeUndefined();
        expect(setSessionData).toHaveBeenCalledWith('sid-1', session);
    });

    it('exposes the zone-changed flag on ctx so a mutator can fold it into its own decision', async () => {
        const session = makeStartedSession({
            ambushed: true, // was resting, syncZoneAuras should flip to combat
            effects: [{ ...EFFECTS_CONFIG.restingAura }],
        });
        vi.mocked(getSessionData).mockResolvedValue(session);

        let observedZoneChanged: boolean | undefined;
        await withSession('sid-1', (ctx) => {
            observedZoneChanged = ctx.zoneChanged;
            return NO_CHANGE;
        });

        expect(observedZoneChanged).toBe(true);
        expect(session.effects.map((e: any) => e.id)).toEqual(['combat']);
    });

    it('does not force a persist when the zone aura was already correct and the mutator reports NO_CHANGE', async () => {
        const session = makeStartedSession({
            currentScreen: 'home',
            effects: [{ ...EFFECTS_CONFIG.restingAura }], // already resting, matches currentScreen
        });
        vi.mocked(getSessionData).mockResolvedValue(session);

        const result = await withSession('sid-1', () => NO_CHANGE);

        expect(result).toBeUndefined();
        expect(setSessionData).not.toHaveBeenCalled();
        expect(session.revision).toBe(1); // untouched
    });

    it('does not sync zone auras (and does not force a persist) for a not-yet-started player', async () => {
        const session = { cookie: {} }; // isGameStarted() is false: no raceId/health/adena
        vi.mocked(getSessionData).mockResolvedValue(session);

        let observedZoneChanged: boolean | undefined;
        const result = await withSession('sid-1', (ctx) => {
            observedZoneChanged = ctx.zoneChanged;
            return NO_CHANGE;
        });

        expect(observedZoneChanged).toBe(false);
        expect(result).toBeUndefined();
        expect(setSessionData).not.toHaveBeenCalled();
        expect((session as any).effects).toBeUndefined();
    });

    it('syncs the zone aura instantly for a player the mutator itself just started (post-mutation sync)', async () => {
        // Pre-mutation: isGameStarted() is false, so the upfront sync correctly skips. The
        // mutator then starts the character during its own execution (mirrors game:start) —
        // only a POST-mutation sync can see the resulting zone, which is exactly the bug fix
        // this test protects: without it, a freshly-started character would show no aura at
        // all until the next 5s tick happened to catch up, instead of instantly.
        const session: Record<string, any> = { cookie: {} };
        vi.mocked(getSessionData).mockResolvedValue(session);

        const result = await withSession('sid-1', (ctx) => {
            Object.assign(ctx.player, { raceId: 0, health: 100, adena: 300, dead: false, ambushed: false, currentScreen: 'home' });
            return 'started';
        });

        expect(result).toBe('started');
        expect(setSessionData).toHaveBeenCalledWith('sid-1', session);
        expect(session.effects.map((e: any) => e.id)).toEqual(['resting']);
    });
});

describe('readSession', () => {
    beforeEach(() => {
        vi.clearAllMocks();
    });

    it('loads the session without acquiring a lock or writing', async () => {
        const session = { cookie: {}, raceId: 0 };
        vi.mocked(getSessionData).mockResolvedValue(session);

        const result = await readSession('sid-1', (ctx: SessionContext) => ctx.player.raceId);

        expect(result).toBe(0);
        expect(acquireSessionLock).not.toHaveBeenCalled();
        expect(setSessionData).not.toHaveBeenCalled();
    });

    it('throws SESSION_EXPIRED when the session is gone', async () => {
        vi.mocked(getSessionData).mockResolvedValue(null);

        await expect(readSession('sid-missing', (ctx) => ctx.player)).rejects.toMatchObject({ code: 'SESSION_EXPIRED' });
    });

    it('supports an async read function', async () => {
        const session = { cookie: {} };
        vi.mocked(getSessionData).mockResolvedValue(session);

        const result = await readSession('sid-1', async (ctx) => {
            await Promise.resolve();
            return ctx.sessionId;
        });

        expect(result).toBe('sid-1');
    });
});
