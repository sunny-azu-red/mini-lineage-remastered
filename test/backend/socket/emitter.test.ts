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

        it('schedules nothing for a player carrying no effects array at all (never-started session)', () => {
            const io = {} as any;
            const tracker: SessionTrackerEntry = { socketIds: new Set(), lastSeen: Date.now() };
            const player = {} as PlayerState; // no `effects` key whatsoever

            expect(() => syncExpiryTimers(io, tracker, 'sid-1', player, vi.fn())).not.toThrow();
            expect(tracker.expiryTimers?.size).toBe(0);
        });

        it('ignores effects with no expiry (permanent auras/curses) and a falsy expiresAt of 0', () => {
            const io = {} as any;
            const tracker: SessionTrackerEntry = { socketIds: new Set(), lastSeen: Date.now() };
            const player: PlayerState = {
                effects: [
                    // Permanent — `expiresAt` omitted entirely, must never get a timeout.
                    { id: 'resting', type: 'aura', emoji: '💤', label: 'Resting', modifiers: [] },
                    // Falsy-but-present expiry, which must be treated as "no expiry" rather
                    // than "expires at the epoch" (which would schedule a 0ms timer storm).
                    { id: 'zero', type: 'buff', emoji: '⭐', label: 'Zero', modifiers: [], expiresAt: 0 },
                ],
            } as any;

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
            const firstTimer = tracker.expiryTimers?.get('x')?.timer;
            syncExpiryTimers(io, tracker, 'sid-1', player, vi.fn());
            expect(tracker.expiryTimers?.get('x')?.timer).toBe(firstTimer);
        });

        /**
         * THE bug behind "the icon vanished a second before the backend noticed".
         *
         * A timer fires 25ms AFTER its deadline, so for those 25ms the effect is due while its
         * timer is still pending. Cleanup used to run over effects narrowed to "still in the
         * future", so a call landing in that window found the effect missing and deleted the
         * pending timer — and nothing ever rescheduled it, because an expired effect could never
         * re-enter that list. Expiry then fell through to the next 5s periodic tick.
         */
        it('keeps a pending timer for an effect that is due but not yet swept', () => {
            const io = {} as any;
            const tracker: SessionTrackerEntry = { socketIds: new Set(), lastSeen: Date.now() };
            const start = Date.now();
            const player: PlayerState = {
                effects: [{ id: 'satisfied', type: 'buff', emoji: '🥓', label: 'Satisfied', modifiers: [], expiresAt: start + 1_000 }],
            } as any;
            const onExpiry = vi.fn();

            syncExpiryTimers(io, tracker, 'sid-1', player, onExpiry);
            const scheduled = tracker.expiryTimers?.get('satisfied')?.timer;

            // Land inside the window: past the deadline, before the timer fires at +25ms. The
            // effect is still in player.effects because nothing has swept it yet.
            vi.advanceTimersByTime(1_010);
            expect(onExpiry).not.toHaveBeenCalled();
            syncExpiryTimers(io, tracker, 'sid-1', player, onExpiry);

            expect(tracker.expiryTimers?.get('satisfied')?.timer).toBe(scheduled);

            // And it still fires, rather than leaving expiry to the periodic tick.
            vi.advanceTimersByTime(50);
            expect(onExpiry).toHaveBeenCalledTimes(1);
        });

        // Timers live in memory, so a restart or a reconnect rebuilds them from a player who may
        // already be overdue. Math.max(0, …) gives that a 0ms timer, so it is swept at once
        // instead of waiting for anything periodic.
        it('schedules an immediate timer for an effect that is already overdue', () => {
            const io = {} as any;
            const tracker: SessionTrackerEntry = { socketIds: new Set(), lastSeen: Date.now() };
            const player: PlayerState = {
                effects: [{ id: 'stale', type: 'buff', emoji: '⭐', label: 'Stale', modifiers: [], expiresAt: Date.now() - 30_000 }],
            } as any;
            const onExpiry = vi.fn();

            syncExpiryTimers(io, tracker, 'sid-1', player, onExpiry);
            expect(tracker.expiryTimers?.size).toBe(1);

            vi.advanceTimersByTime(1);
            expect(onExpiry).toHaveBeenCalledWith('sid-1');
        });

        /**
         * `applyEffect` refreshes an effect in place under the SAME id — re-applied Hexed, or
         * buying the same food twice — so the deadline moves while the id does not. Keying only
         * on the id kept the timer for the OLD deadline: it fired early, found nothing expired,
         * and left the new deadline with no timer at all, pushing expiry out to the next periodic
         * tick. That is why the client dropped an icon seconds before the server logged it.
         */
        it('reschedules when an effect is refreshed to a later deadline under the same id', () => {
            const io = {} as any;
            const tracker: SessionTrackerEntry = { socketIds: new Set(), lastSeen: Date.now() };
            const start = Date.now();
            const player: PlayerState = {
                effects: [{ id: 'hexed', type: 'debuff', emoji: '👁️', label: 'Hexed', modifiers: [], expiresAt: start + 60_000 }],
            } as any;
            const onExpiry = vi.fn();

            syncExpiryTimers(io, tracker, 'sid-1', player, onExpiry);
            const firstTimer = tracker.expiryTimers?.get('hexed')?.timer;

            // Re-applied 30s in: same id, deadline pushed out to start + 90s.
            vi.advanceTimersByTime(30_000);
            player.effects = [{ id: 'hexed', type: 'debuff', emoji: '👁️', label: 'Hexed', modifiers: [], expiresAt: start + 90_000 }] as any;
            syncExpiryTimers(io, tracker, 'sid-1', player, onExpiry);

            expect(tracker.expiryTimers?.get('hexed')?.timer).not.toBe(firstTimer);
            expect(tracker.expiryTimers?.get('hexed')?.expiresAt).toBe(start + 90_000);

            // The original deadline must pass in silence — the old timer is gone.
            vi.advanceTimersByTime(30_100);
            expect(onExpiry).not.toHaveBeenCalled();

            // The new one fires on time, once.
            vi.advanceTimersByTime(30_000);
            expect(onExpiry).toHaveBeenCalledTimes(1);
            expect(onExpiry).toHaveBeenCalledWith('sid-1');
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
                expiryTimers: new Map([['x', { expiresAt: Date.now() + 10_000, timer }]]),
            });

            cleanupStaleSessions(Date.now());

            expect(clearSpy).toHaveBeenCalledWith(timer);
            vi.useRealTimers();
        });
    });
});
