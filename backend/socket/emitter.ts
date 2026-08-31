import type { Server as SocketIOServer } from 'socket.io';
import type { HydratePayload, PlayerSnapshot, FlashView } from '@shared/contract';
import type { SessionTrackerEntry, PlayerState } from '@/interface';
import { SESSION_CONFIG } from '@/constant/game.constant';
import { logger } from '@/config/logger.config';
import { formatSessionId } from '@/util/format.util';

/** Multi-tab session tracking + push emission. */
export const sessionTracker = new Map<string, SessionTrackerEntry>();

export function trackSocket(_io: SocketIOServer, sessionId: string, socketId: string): void {
    const tracker = sessionTracker.get(sessionId) ?? { socketIds: new Set<string>(), lastSeen: 0 };
    tracker.socketIds.add(socketId);
    tracker.lastSeen = Date.now();
    sessionTracker.set(sessionId, tracker);
}

export function untrackSocket(sessionId: string, socketId: string): void {
    const tracker = sessionTracker.get(sessionId);
    if (!tracker)
        return;

    tracker.socketIds.delete(socketId);
    tracker.lastSeen = Date.now();
}

function emitToTracked(io: SocketIOServer, sessionId: string, event: string, payload: unknown, excludeSocketId?: string): void {
    sessionTracker.get(sessionId)?.socketIds.forEach(socketId => {
        if (socketId !== excludeSocketId)
            io.sockets.sockets.get(socketId)?.emit(event, payload);
    });
}

export function emitHydrate(io: SocketIOServer, sessionId: string, payload: HydratePayload): void {
    emitToTracked(io, sessionId, 'hydrate', payload);
}

/**
 * `excludeSocketId` is REQUIRED for a mutation's own acting socket: it already gets the
 * authoritative result via its ack, and this push carries no transition detection, so if it
 * won the race it could clobber the baseline that ack's handler needs and freeze the UI.
 */
export function emitStateUpdate(io: SocketIOServer, sessionId: string, payload: Partial<PlayerSnapshot>, excludeSocketId?: string): void {
    emitToTracked(io, sessionId, 'state:update', payload, excludeSocketId);
}

export function emitNotice(io: SocketIOServer, sessionId: string, notice: FlashView): void {
    emitToTracked(io, sessionId, 'notice', notice);
}

/**
 * Schedules an exact timeout per active timed effect so expiry fires to the millisecond rather
 * than waiting for the next 5s tick. `onExpiry` is a parameter (not a direct import of
 * processSessionTick) purely to avoid an emitter <-> tick import cycle.
 */
export function syncExpiryTimers(
    _io: SocketIOServer,
    tracker: SessionTrackerEntry,
    sessionId: string,
    player: PlayerState,
    onExpiry: (sessionId: string) => void,
): void {
    const timers = tracker.expiryTimers ??= new Map();
    const now = Date.now();

    /**
     * Every effect carrying a real deadline — deliberately NOT narrowed to "still in the future".
     * Cleanup and scheduling below read this same list, because they are answering the same
     * question: does a timer for exactly this effect and deadline still belong?
     *
     * Narrowing it broke that. A timer fires 25ms AFTER its deadline, so for those 25ms an effect
     * is due while its timer is still pending — and a call landing in that window found the effect
     * missing from the list and deleted the pending timer. Nothing ever rescheduled it, since an
     * expired effect could never re-enter the list, so expiry fell through to the next periodic
     * tick, seconds late.
     *
     * Truthiness rather than `!== undefined` on purpose: a falsy-but-present `expiresAt: 0` means
     * "no expiry", not "expired in 1970".
     */
    const timed = (player.effects ?? []).filter(e => e.expiresAt);

    // Compares the DEADLINE, not just the id. `applyEffect` refreshes an effect in place under the
    // same id (re-applied Hexed, buying the same food twice), so an id-only check kept the timer
    // for the OLD deadline and never scheduled the new one.
    for (const [id, entry] of timers.entries()) {
        if (!timed.some(e => e.id === id && e.expiresAt === entry.expiresAt)) {
            clearTimeout(entry.timer);
            timers.delete(id);
        }
    }

    for (const effect of timed) {
        // Only ever skips a timer already scheduled for exactly this effect's current deadline —
        // a moved deadline was cleared above.
        if (timers.has(effect.id))
            continue;

        timers.set(effect.id, {
            expiresAt: effect.expiresAt!,
            // `Math.max(0, …)` earns a second job here: an effect that is ALREADY overdue when the
            // timers are rebuilt — after a server restart, or on reconnect — gets a 0ms timer and
            // is swept at once, rather than waiting for anything periodic.
            timer: setTimeout(() => {
                timers.delete(effect.id);
                onExpiry(sessionId);
            }, Math.max(0, effect.expiresAt! - now + 25)),
        });
    }
}

/** Drops tracker entries with no sockets that have been idle past the grace period. */
export function cleanupStaleSessions(now: number): void {
    sessionTracker.forEach((tracker, sessionId) => {
        if (tracker.socketIds.size > 0 || now - tracker.lastSeen <= SESSION_CONFIG.gracePeriodMs)
            return;

        logger.debug(`[SOCKET:${formatSessionId(sessionId)}] \x1b[34mCleaning up stale session\x1b[0m`);
        tracker.expiryTimers?.forEach(entry => clearTimeout(entry.timer));
        tracker.expiryTimers?.clear();
        sessionTracker.delete(sessionId);
    });
}
