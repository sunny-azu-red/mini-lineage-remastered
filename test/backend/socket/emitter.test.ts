import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import {
    sessionTracker,
    trackSocket,
    untrackSocket,
    emitHydrate,
    emitStateUpdate,
    emitNotice,
    scheduleNextExpiry,
    cleanupStaleSessions,
} from '@/socket/emitter';
import { SESSION_CONFIG } from '@/constant/game.constant';
import type { PlayerState, SessionTrackerEntry } from '@/interface';

function makeIo(sockets: Record<string, { emit: ReturnType<typeof vi.fn> }>) {
    return {
        sockets: {
            sockets: {
                get: (id: string) => sockets[id],
            },
        },
    } as any;
}

describe('emitter', () => {
    beforeEach(() => {
        sessionTracker.clear();
    });

    describe('trackSocket / untrackSocket', () => {
        it('creates a tracker on first connect and adds the socket id', () => {
            trackSocket({} as any, 'sid-1', 'sock-1');
            const tracker = sessionTracker.get('sid-1');
            expect(tracker?.socketIds.has('sock-1')).toBe(true);
        });

        it('adds a second socket to the same session (multi-tab)', () => {
            trackSocket({} as any, 'sid-1', 'sock-1');
            trackSocket({} as any, 'sid-1', 'sock-2');
            const tracker = sessionTracker.get('sid-1');
            expect(tracker?.socketIds.size).toBe(2);
        });

        it('removes a socket id on untrack, leaving the tracker if other sockets remain', () => {
            trackSocket({} as any, 'sid-1', 'sock-1');
            trackSocket({} as any, 'sid-1', 'sock-2');
            untrackSocket('sid-1', 'sock-1');

            const tracker = sessionTracker.get('sid-1');
            expect(tracker?.socketIds.has('sock-1')).toBe(false);
            expect(tracker?.socketIds.has('sock-2')).toBe(true);
        });

        it('is a no-op untracking a session with no tracker', () => {
            expect(() => untrackSocket('nonexistent', 'sock-1')).not.toThrow();
        });
    });

    describe('emitHydrate / emitStateUpdate / emitNotice (multi-tab fan-out)', () => {
        it('emits to every socket tracked under the session', () => {
            const sock1 = { emit: vi.fn() };
            const sock2 = { emit: vi.fn() };
            const io = makeIo({ 'sock-1': sock1, 'sock-2': sock2 });

            trackSocket(io, 'sid-1', 'sock-1');
            trackSocket(io, 'sid-1', 'sock-2');

            const payload = { player: null, catalog: {} as any };
            emitHydrate(io, 'sid-1', payload);

            expect(sock1.emit).toHaveBeenCalledWith('hydrate', payload);
            expect(sock2.emit).toHaveBeenCalledWith('hydrate', payload);
        });

        it('emitStateUpdate sends the "state:update" event', () => {
            const sock1 = { emit: vi.fn() };
            const io = makeIo({ 'sock-1': sock1 });
            trackSocket(io, 'sid-1', 'sock-1');

            emitStateUpdate(io, 'sid-1', { health: 50 });
            expect(sock1.emit).toHaveBeenCalledWith('state:update', { health: 50 });
        });

        it('emitStateUpdate excludes the acting socket when told to, but still reaches every other tab', () => {
            // Regression test for the game:restart screen-freeze bug: the acting socket must
            // never receive this push for its own mutation (it already got the full result via
            // its own ack) — receiving both could race, since the ack's handler and this push's
            // handler don't necessarily apply their updates in the same order.
            const acting = { emit: vi.fn() };
            const otherTab = { emit: vi.fn() };
            const io = makeIo({ 'sock-acting': acting, 'sock-other': otherTab });
            trackSocket(io, 'sid-1', 'sock-acting');
            trackSocket(io, 'sid-1', 'sock-other');

            emitStateUpdate(io, 'sid-1', { health: 50 }, 'sock-acting');

            expect(acting.emit).not.toHaveBeenCalled();
            expect(otherTab.emit).toHaveBeenCalledWith('state:update', { health: 50 });
        });

        it('emitNotice sends the "notice" event', () => {
            const sock1 = { emit: vi.fn() };
            const io = makeIo({ 'sock-1': sock1 });
            trackSocket(io, 'sid-1', 'sock-1');

            const notice = { text: 'hi', type: 'info' as const };
            emitNotice(io, 'sid-1', notice);
            expect(sock1.emit).toHaveBeenCalledWith('notice', notice);
        });

        it('is a no-op when the session has no tracker', () => {
            const io = makeIo({});
            expect(() => emitStateUpdate(io, 'unknown-sid', {})).not.toThrow();
        });

        it('skips a tracked socket id that Socket.IO no longer has connected', () => {
            const io = makeIo({}); // "sock-1" is tracked but not actually connected anymore
            trackSocket(io, 'sid-1', 'sock-1');
            expect(() => emitStateUpdate(io, 'sid-1', {})).not.toThrow();
        });
    });

    /**
     * ONE timer per session, at the earliest upcoming deadline. Replaces a timer-per-effect map
     * whose scheduling and cleanup halves had to agree on which timers still applied — every bug
     * in the old design came from them disagreeing. There is nothing here to disagree about.
     */
    describe('scheduleNextExpiry', () => {
        const io = {} as any;
        let tracker: SessionTrackerEntry;

        beforeEach(() => {
            vi.useFakeTimers();
            tracker = { socketIds: new Set(), lastSeen: Date.now() };
        });

        afterEach(() => {
            vi.useRealTimers();
        });

        const effect = (id: string, expiresAt?: number) =>
            ({ id, type: 'buff', emoji: '⭐', label: id, modifiers: [], expiresAt }) as any;

        const player = (...effects: any[]) => ({ effects } as PlayerState);

        it('arms nothing for a player with no timed effects', () => {
            const onExpiry = vi.fn();

            scheduleNextExpiry(tracker, 'sid-1', player(effect('resting')), onExpiry);

            expect(tracker.expiryTimer).toBeUndefined();
            vi.advanceTimersByTime(600_000);
            expect(onExpiry).not.toHaveBeenCalled();
        });

        it('arms nothing for a player carrying no effects array at all', () => {
            expect(() => scheduleNextExpiry(tracker, 'sid-1', {} as PlayerState, vi.fn())).not.toThrow();
            expect(tracker.expiryTimer).toBeUndefined();
        });

        // A falsy-but-present 0 means "no expiry", not "expired in 1970" — which would arm a
        // 0ms timer storm.
        it('treats a falsy expiresAt of 0 as no expiry', () => {
            scheduleNextExpiry(tracker, 'sid-1', player(effect('zero', 0)), vi.fn());

            expect(tracker.expiryTimer).toBeUndefined();
        });

        it('arms for the EARLIEST deadline when several are pending', () => {
            const now = Date.now();
            const onExpiry = vi.fn();

            scheduleNextExpiry(tracker, 'sid-1', player(
                effect('late', now + 90_000),
                effect('soon', now + 5_000),
                effect('middle', now + 30_000),
            ), onExpiry);

            vi.advanceTimersByTime(5_100);
            expect(onExpiry).toHaveBeenCalledExactlyOnceWith('sid-1');
        });

        it('fires once for several effects due at the same moment', () => {
            const at = Date.now() + 1_000;
            const onExpiry = vi.fn();

            scheduleNextExpiry(tracker, 'sid-1', player(effect('a', at), effect('b', at)), onExpiry);

            vi.advanceTimersByTime(1_100);
            expect(onExpiry).toHaveBeenCalledTimes(1);
        });

        // Re-arming is unconditional, so a deadline that moved — a re-applied Hexed, the same food
        // bought twice — needs no detection.
        it('re-arms for a refreshed deadline, and the old one passes in silence', () => {
            const now = Date.now();
            const onExpiry = vi.fn();

            scheduleNextExpiry(tracker, 'sid-1', player(effect('hexed', now + 10_000)), onExpiry);
            scheduleNextExpiry(tracker, 'sid-1', player(effect('hexed', now + 40_000)), onExpiry);

            vi.advanceTimersByTime(10_100);
            expect(onExpiry).not.toHaveBeenCalled();

            vi.advanceTimersByTime(30_000);
            expect(onExpiry).toHaveBeenCalledTimes(1);
        });

        it('re-arms for the next deadline after one fires', () => {
            const now = Date.now();
            const onExpiry = vi.fn();
            const remaining = player(effect('late', now + 20_000));

            scheduleNextExpiry(tracker, 'sid-1', player(effect('soon', now + 2_000), effect('late', now + 20_000)), onExpiry);
            vi.advanceTimersByTime(2_100);
            expect(onExpiry).toHaveBeenCalledTimes(1);
            expect(tracker.expiryTimer).toBeUndefined();   // cleared itself on firing

            // What the expiry-triggered session load does once the first effect is swept.
            scheduleNextExpiry(tracker, 'sid-1', remaining, onExpiry);
            vi.advanceTimersByTime(18_000);
            expect(onExpiry).toHaveBeenCalledTimes(2);
        });

        // Timers live in memory, so a restart leaves the stored player already overdue. Firing
        // immediately is what gets it swept, rather than waiting for anything periodic.
        it('fires immediately for a deadline already in the past', () => {
            const onExpiry = vi.fn();

            scheduleNextExpiry(tracker, 'sid-1', player(effect('stale', Date.now() - 30_000)), onExpiry);

            vi.advanceTimersByTime(1);
            expect(onExpiry).toHaveBeenCalledWith('sid-1');
        });

        it('drops the pending timer when the effects are gone entirely', () => {
            const onExpiry = vi.fn();

            scheduleNextExpiry(tracker, 'sid-1', player(effect('a', Date.now() + 5_000)), onExpiry);
            scheduleNextExpiry(tracker, 'sid-1', player(), onExpiry);

            expect(tracker.expiryTimer).toBeUndefined();
            vi.advanceTimersByTime(10_000);
            expect(onExpiry).not.toHaveBeenCalled();
        });
    });

    describe('cleanupStaleSessions', () => {
        it('removes a tracker with no sockets that has exceeded the grace period', () => {
            sessionTracker.set('sid-stale', { socketIds: new Set(), lastSeen: Date.now() - SESSION_CONFIG.gracePeriodMs - 1 });
            cleanupStaleSessions(Date.now());
            expect(sessionTracker.has('sid-stale')).toBe(false);
        });

        it('keeps a tracker with no sockets that is still within the grace period', () => {
            sessionTracker.set('sid-fresh', { socketIds: new Set(), lastSeen: Date.now() });
            cleanupStaleSessions(Date.now());
            expect(sessionTracker.has('sid-fresh')).toBe(true);
        });

        it('keeps a tracker that still has connected sockets, regardless of lastSeen', () => {
            sessionTracker.set('sid-active', { socketIds: new Set(['sock-1']), lastSeen: 0 });
            cleanupStaleSessions(Date.now());
            expect(sessionTracker.has('sid-active')).toBe(true);
        });

        it('clears any pending expiry timers when removing a stale session', () => {
            vi.useFakeTimers();
            const timer = setTimeout(() => {}, 10_000);
            const clearSpy = vi.spyOn(global, 'clearTimeout');
            sessionTracker.set('sid-stale', {
                socketIds: new Set(),
                lastSeen: Date.now() - SESSION_CONFIG.gracePeriodMs - 1,
                expiryTimer: timer,
            });

            cleanupStaleSessions(Date.now());

            expect(clearSpy).toHaveBeenCalledWith(timer);
            vi.useRealTimers();
        });
    });
});
