import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';

vi.mock('@/socket/session', async (importOriginal) => {
    const actual = await importOriginal<typeof import('@/socket/session')>();
    return { ...actual, withSession: vi.fn() };
});

vi.mock('@/service/player.service', () => ({
    processRegenTick: vi.fn(),
    processEffectExpiry: vi.fn(),
    isGameStarted: vi.fn(),
    // processSessionTick's tick-result logging (ported from the old game's [TICK:...] debug
    // line) calls this unconditionally for any started session — stub a sensible default so
    // every test in this file can complete without needing its own stats setup.
    getPlayerStats: vi.fn(() => ({ maxHealth: 100, regen: 5 })),
}));

vi.mock('@/socket/emitter', () => ({
    emitStateUpdate: vi.fn(),
    syncExpiryTimers: vi.fn(),
    cleanupStaleSessions: vi.fn(),
    sessionTracker: new Map(),
}));

vi.mock('@/socket/serializer/player.serializer', () => ({
    buildPlayerSnapshot: vi.fn(() => ({ revision: 1 })),
}));

import { processSessionTick, startTickLoop, refreshExpiryTimers } from '@/socket/tick';
import { withSession, NO_CHANGE } from '@/socket/session';
import * as playerService from '@/service/player.service';
import { emitStateUpdate, syncExpiryTimers, cleanupStaleSessions, sessionTracker } from '@/socket/emitter';
import { buildPlayerSnapshot } from '@/socket/serializer/player.serializer';
import { SocketError } from '@/socket/error';
import { TICK_CONFIG } from '@/constant/game.constant';
import type { SessionTrackerEntry } from '@/interface';

describe('processSessionTick', () => {
    const io = {} as any;
    let tracker: SessionTrackerEntry;

    beforeEach(() => {
        vi.clearAllMocks();
        sessionTracker.clear();
        tracker = { socketIds: new Set(['sock-1']), lastSeen: Date.now() };
        // processSessionTick now refreshes expiry timers via the shared refreshExpiryTimers()
        // helper (Fix 2), which looks the tracker up from the real sessionTracker map by
        // sessionId rather than using the `tracker` argument directly — register it here so
        // that lookup succeeds, mirroring how the real sessionTracker map is populated via
        // trackSocket() in production.
        sessionTracker.set('sid-1', tracker);
    });

    it('emits the built snapshot when processRegenTick reports a change', async () => {
        const player = { raceId: 0 };
        vi.mocked(withSession).mockImplementation(async (sid: string, mutate: any) =>
            mutate({ sessionId: sid, session: {}, player, zoneChanged: false }));
        vi.mocked(playerService.isGameStarted).mockReturnValue(true);
        vi.mocked(playerService.processRegenTick).mockReturnValue(true);

        await processSessionTick(io, tracker, 'sid-1', 'regen');

        expect(playerService.processRegenTick).toHaveBeenCalledWith(player);
        expect(buildPlayerSnapshot).toHaveBeenCalledWith(player);
        expect(emitStateUpdate).toHaveBeenCalledWith(io, 'sid-1', { revision: 1 });
        expect(syncExpiryTimers).toHaveBeenCalledWith(io, tracker, 'sid-1', player, expect.any(Function));
    });

    /**
     * A no-op tick must not persist or broadcast — but it MUST still re-derive the session's expiry
     * timers. That is exactly when a missing or stale timer needs replacing, and gating the
     * rescheduling on "something changed" is what let one stale timer delay an effect's expiry by a
     * whole tick interval, so the client dropped the icon seconds before the server logged it.
     */
    it('re-syncs expiry timers but does not persist or emit when neither processRegenTick nor the zone report a change', async () => {
        const player = { raceId: 0 };
        vi.mocked(withSession).mockImplementation(async (sid: string, mutate: any) => {
            const result = mutate({ sessionId: sid, session: {}, player, zoneChanged: false });
            return result === NO_CHANGE ? undefined : result;
        });
        vi.mocked(playerService.isGameStarted).mockReturnValue(true);
        vi.mocked(playerService.processRegenTick).mockReturnValue(false);

        await processSessionTick(io, tracker, 'sid-1', 'regen');

        expect(emitStateUpdate).not.toHaveBeenCalled();
        expect(syncExpiryTimers).toHaveBeenCalledWith(io, tracker, 'sid-1', player, expect.any(Function));
    });

    it('regression (Fix 8): builds and emits a snapshot when the zone alone changed (e.g. a reconnect resolved a different screen than what was persisted), even though processRegenTick itself reports no change', async () => {
        // withSession's own automatic syncZoneAuras call (session.ts) is what would set
        // ctx.zoneChanged to true here in real production use, whenever currentScreen no
        // longer matches the persisted aura. withSession is mocked in this file, so
        // ctx.zoneChanged is supplied directly to isolate tick.ts's own responsibility: folding
        // it into its "did anything change" decision instead of relying on processRegenTick alone,
        // which knows nothing about zones.
        const player = { raceId: 0, currentScreen: 'home' };
        vi.mocked(withSession).mockImplementation(async (sid: string, mutate: any) => {
            const result = mutate({ sessionId: sid, session: {}, player, zoneChanged: true });
            return result === NO_CHANGE ? undefined : result;
        });
        vi.mocked(playerService.isGameStarted).mockReturnValue(true);
        vi.mocked(playerService.processRegenTick).mockReturnValue(false);

        await processSessionTick(io, tracker, 'sid-1', 'regen');

        expect(buildPlayerSnapshot).toHaveBeenCalledWith(player);
        expect(emitStateUpdate).toHaveBeenCalledWith(io, 'sid-1', { revision: 1 });
        expect(syncExpiryTimers).toHaveBeenCalledWith(io, tracker, 'sid-1', player, expect.any(Function));
    });

    it('skips processRegenTick entirely for a not-yet-started session', async () => {
        const player = {};
        vi.mocked(withSession).mockImplementation(async (sid: string, mutate: any) => {
            const result = mutate({ sessionId: sid, session: {}, player, zoneChanged: false });
            return result === NO_CHANGE ? undefined : result;
        });
        vi.mocked(playerService.isGameStarted).mockReturnValue(false);

        await processSessionTick(io, tracker, 'sid-1', 'regen');

        expect(playerService.processRegenTick).not.toHaveBeenCalled();
        expect(emitStateUpdate).not.toHaveBeenCalled();
    });

    it('swallows SESSION_EXPIRED (vanished session) without crashing the loop', async () => {
        vi.mocked(withSession).mockRejectedValue(new SocketError('SESSION_EXPIRED', 'gone'));

        await expect(processSessionTick(io, tracker, 'sid-1', 'regen')).resolves.toBeUndefined();
        expect(emitStateUpdate).not.toHaveBeenCalled();
    });

    it('swallows any other unexpected error without crashing the loop', async () => {
        vi.mocked(withSession).mockRejectedValue(new Error('boom'));
        await expect(processSessionTick(io, tracker, 'sid-1', 'regen')).resolves.toBeUndefined();
    });

    it('runs the expiry sweep, and never regen, for an expiry-triggered firing', async () => {
        const player = { raceId: 0 };
        vi.mocked(withSession).mockImplementation(async (sid: string, mutate: any) =>
            mutate({ sessionId: sid, session: {}, player, zoneChanged: false }));
        vi.mocked(playerService.isGameStarted).mockReturnValue(true);
        vi.mocked(playerService.processEffectExpiry).mockReturnValue(true);

        await processSessionTick(io, tracker, 'sid-1', 'expiry');

        expect(playerService.processEffectExpiry).toHaveBeenCalledWith(player);
        expect(playerService.processRegenTick).not.toHaveBeenCalled();
    });
});

describe('refreshExpiryTimers (Fix 2 — shared home for the duplicated onExpiry closure)', () => {
    const io = {} as any;
    let tracker: SessionTrackerEntry;

    beforeEach(() => {
        vi.clearAllMocks();
        sessionTracker.clear();
        tracker = { socketIds: new Set(['sock-1']), lastSeen: Date.now() };
    });

    it('looks the tracker up from sessionTracker by sessionId and delegates to syncExpiryTimers', () => {
        const player = { raceId: 0 } as any;
        sessionTracker.set('sid-1', tracker);

        refreshExpiryTimers(io, 'sid-1', player);

        expect(syncExpiryTimers).toHaveBeenCalledWith(io, tracker, 'sid-1', player, expect.any(Function));
    });

    it('is a no-op when the session has no tracker (never connected, or already cleaned up)', () => {
        refreshExpiryTimers(io, 'sid-unknown', {} as any);
        expect(syncExpiryTimers).not.toHaveBeenCalled();
    });

    it('the onExpiry callback re-processes the session as an expiry-only firing', async () => {
        // This is the exact behavior that used to live as an inline closure duplicated in
        // both backend/socket/index.ts's connection handler and processSessionTick above —
        // confirming it still works identically now that both call through this one function.
        sessionTracker.set('sid-1', tracker);
        refreshExpiryTimers(io, 'sid-1', { raceId: 0 } as any);

        const onExpiry = vi.mocked(syncExpiryTimers).mock.calls[0][4];

        const expiredPlayer = { raceId: 0 };
        vi.mocked(withSession).mockImplementation(async (sid: string, mutate: any) =>
            mutate({ sessionId: sid, session: {}, player: expiredPlayer, zoneChanged: false }));
        vi.mocked(playerService.isGameStarted).mockReturnValue(true);
        vi.mocked(playerService.processEffectExpiry).mockReturnValue(true);

        onExpiry('sid-1');
        await new Promise(resolve => setImmediate(resolve));

        expect(playerService.processEffectExpiry).toHaveBeenCalledWith(expiredPlayer);
        expect(playerService.processRegenTick).not.toHaveBeenCalled();
        expect(emitStateUpdate).toHaveBeenCalledWith(io, 'sid-1', { revision: 1 });
    });

    it('the onExpiry callback is a no-op if the tracker vanished before the timer fired', async () => {
        sessionTracker.set('sid-1', tracker);
        refreshExpiryTimers(io, 'sid-1', { raceId: 0 } as any);

        const onExpiry = vi.mocked(syncExpiryTimers).mock.calls[0][4];
        sessionTracker.delete('sid-1');

        onExpiry('sid-1');
        await new Promise(resolve => setImmediate(resolve));

        expect(withSession).not.toHaveBeenCalled();
    });
});

describe('startTickLoop', () => {
    beforeEach(() => {
        vi.clearAllMocks();
        vi.useFakeTimers();
        sessionTracker.clear();
    });

    afterEach(() => {
        vi.useRealTimers();
    });

    it('sets an interval at TICK_CONFIG.intervalMs that prunes stale sessions then ticks the rest', async () => {
        sessionTracker.set('sid-1', { socketIds: new Set(['sock-1']), lastSeen: Date.now() });
        vi.mocked(withSession).mockResolvedValue(undefined);

        const handle = startTickLoop({} as any);
        expect(handle).toBeDefined();

        vi.advanceTimersByTime(TICK_CONFIG.intervalMs);
        await vi.runAllTicks();

        expect(cleanupStaleSessions).toHaveBeenCalled();
        expect(withSession).toHaveBeenCalledWith('sid-1', expect.any(Function));

        clearInterval(handle);
    });
});
