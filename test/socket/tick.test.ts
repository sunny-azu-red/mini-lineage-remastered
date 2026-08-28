import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';

vi.mock('@/socket/session', async (importOriginal) => {
    const actual = await importOriginal<typeof import('@/socket/session')>();
    return { ...actual, withSession: vi.fn() };
});

vi.mock('@/service/player.service', () => ({
    processTick: vi.fn(),
    isGameStarted: vi.fn(),
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

import { processSessionTick, startTickLoop } from '@/socket/tick';
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
        tracker = { socketIds: new Set(['sock-1']), lastSeen: Date.now() };
    });

    it('emits the built snapshot when processTick reports a change', async () => {
        const player = { raceId: 0 };
        vi.mocked(withSession).mockImplementation(async (sid: string, mutate: any) =>
            mutate({ sessionId: sid, session: {}, player, zoneChanged: false }));
        vi.mocked(playerService.isGameStarted).mockReturnValue(true);
        vi.mocked(playerService.processTick).mockReturnValue(true);

        await processSessionTick(io, tracker, 'sid-1', { applyRegen: true });

        expect(playerService.processTick).toHaveBeenCalledWith(player, { applyRegen: true });
        expect(buildPlayerSnapshot).toHaveBeenCalledWith(player);
        expect(emitStateUpdate).toHaveBeenCalledWith(io, 'sid-1', { revision: 1 });
        expect(syncExpiryTimers).toHaveBeenCalledWith(io, tracker, 'sid-1', player, expect.any(Function));
    });

    it('does not persist or emit when neither processTick nor the zone report a change', async () => {
        const player = { raceId: 0 };
        vi.mocked(withSession).mockImplementation(async (sid: string, mutate: any) => {
            const result = mutate({ sessionId: sid, session: {}, player, zoneChanged: false });
            return result === NO_CHANGE ? undefined : result;
        });
        vi.mocked(playerService.isGameStarted).mockReturnValue(true);
        vi.mocked(playerService.processTick).mockReturnValue(false);

        await processSessionTick(io, tracker, 'sid-1');

        expect(emitStateUpdate).not.toHaveBeenCalled();
        expect(syncExpiryTimers).not.toHaveBeenCalled();
    });

    it('regression (Fix 8): builds and emits a snapshot when the zone alone changed (e.g. the combat linger window just expired), even though processTick itself reports no change', async () => {
        // withSession's own automatic syncZoneAuras call (session.ts) is what would set
        // ctx.zoneChanged to true here in real production use, once
        // Date.now() - lastFightAt >= TICK_CONFIG.combatLingerMs flips combat -> resting.
        // withSession is mocked in this file, so ctx.zoneChanged is supplied directly to
        // isolate tick.ts's own responsibility: folding it into its "did anything change"
        // decision instead of relying on processTick alone, which knows nothing about zones.
        const player = { raceId: 0, lastFightAt: Date.now() - TICK_CONFIG.combatLingerMs - 1 };
        vi.mocked(withSession).mockImplementation(async (sid: string, mutate: any) => {
            const result = mutate({ sessionId: sid, session: {}, player, zoneChanged: true });
            return result === NO_CHANGE ? undefined : result;
        });
        vi.mocked(playerService.isGameStarted).mockReturnValue(true);
        vi.mocked(playerService.processTick).mockReturnValue(false);

        await processSessionTick(io, tracker, 'sid-1');

        expect(buildPlayerSnapshot).toHaveBeenCalledWith(player);
        expect(emitStateUpdate).toHaveBeenCalledWith(io, 'sid-1', { revision: 1 });
        expect(syncExpiryTimers).toHaveBeenCalledWith(io, tracker, 'sid-1', player, expect.any(Function));
    });

    it('skips processTick entirely for a not-yet-started session', async () => {
        const player = {};
        vi.mocked(withSession).mockImplementation(async (sid: string, mutate: any) => {
            const result = mutate({ sessionId: sid, session: {}, player, zoneChanged: false });
            return result === NO_CHANGE ? undefined : result;
        });
        vi.mocked(playerService.isGameStarted).mockReturnValue(false);

        await processSessionTick(io, tracker, 'sid-1');

        expect(playerService.processTick).not.toHaveBeenCalled();
        expect(emitStateUpdate).not.toHaveBeenCalled();
    });

    it('swallows SESSION_EXPIRED (vanished session) without crashing the loop', async () => {
        vi.mocked(withSession).mockRejectedValue(new SocketError('SESSION_EXPIRED', 'gone'));

        await expect(processSessionTick(io, tracker, 'sid-1')).resolves.toBeUndefined();
        expect(emitStateUpdate).not.toHaveBeenCalled();
    });

    it('swallows any other unexpected error without crashing the loop', async () => {
        vi.mocked(withSession).mockRejectedValue(new Error('boom'));
        await expect(processSessionTick(io, tracker, 'sid-1')).resolves.toBeUndefined();
    });

    it('passes applyRegen:false through to processTick for expiry-only ticks', async () => {
        const player = { raceId: 0 };
        vi.mocked(withSession).mockImplementation(async (sid: string, mutate: any) =>
            mutate({ sessionId: sid, session: {}, player, zoneChanged: false }));
        vi.mocked(playerService.isGameStarted).mockReturnValue(true);
        vi.mocked(playerService.processTick).mockReturnValue(true);

        await processSessionTick(io, tracker, 'sid-1', { applyRegen: false });

        expect(playerService.processTick).toHaveBeenCalledWith(player, { applyRegen: false });
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
