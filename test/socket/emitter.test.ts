import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import {
    sessionTracker,
    trackSocket,
    untrackSocket,
    emitHydrate,
    emitStateUpdate,
    emitNotice,
    syncExpiryTimers,
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

    describe('syncExpiryTimers', () => {
        beforeEach(() => vi.useFakeTimers());
        afterEach(() => vi.useRealTimers());

        it('schedules a timer that fires onExpiry once an effect expires', () => {
            const io = {} as any;
            const tracker: SessionTrackerEntry = { socketIds: new Set(), lastSeen: Date.now() };
            const player: PlayerState = {
                effects: [{ id: 'x', type: 'buff', emoji: '⭐', label: 'X', modifiers: [], expiresAt: Date.now() + 1000 }],
            } as any;
            const onExpiry = vi.fn();

            syncExpiryTimers(io, tracker, 'sid-1', player, onExpiry);
            expect(tracker.expiryTimers?.size).toBe(1);

            vi.advanceTimersByTime(1100);
            expect(onExpiry).toHaveBeenCalledWith('sid-1');
        });

        it('clears a timer for an effect that is no longer active', () => {
            const io = {} as any;
            const tracker: SessionTrackerEntry = { socketIds: new Set(), lastSeen: Date.now() };
            const player: PlayerState = {
                effects: [{ id: 'x', type: 'buff', emoji: '⭐', label: 'X', modifiers: [], expiresAt: Date.now() + 1000 }],
            } as any;

            syncExpiryTimers(io, tracker, 'sid-1', player, vi.fn());
            expect(tracker.expiryTimers?.size).toBe(1);

            player.effects = [];
            syncExpiryTimers(io, tracker, 'sid-1', player, vi.fn());
            expect(tracker.expiryTimers?.size).toBe(0);
        });

        it('does not double-schedule an already-scheduled effect', () => {
            const io = {} as any;
            const tracker: SessionTrackerEntry = { socketIds: new Set(), lastSeen: Date.now() };
            const player: PlayerState = {
                effects: [{ id: 'x', type: 'buff', emoji: '⭐', label: 'X', modifiers: [], expiresAt: Date.now() + 5000 }],
            } as any;

            syncExpiryTimers(io, tracker, 'sid-1', player, vi.fn());
            const firstTimer = tracker.expiryTimers?.get('x');
            syncExpiryTimers(io, tracker, 'sid-1', player, vi.fn());
            expect(tracker.expiryTimers?.get('x')).toBe(firstTimer);
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
                expiryTimers: new Map([['x', timer]]),
            });

            cleanupStaleSessions(Date.now());

            expect(clearSpy).toHaveBeenCalledWith(timer);
            vi.useRealTimers();
        });
    });
});
