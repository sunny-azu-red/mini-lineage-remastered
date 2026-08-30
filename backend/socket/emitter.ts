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
    const active = (player.effects ?? []).filter(e => e.expiresAt && e.expiresAt > now);
    const activeIds = new Set(active.map(e => e.id));

    for (const [id, timer] of timers.entries()) {
        if (!activeIds.has(id)) {
            clearTimeout(timer);
            timers.delete(id);
        }
    }

    for (const effect of active) {
        if (timers.has(effect.id))
            continue;

        timers.set(effect.id, setTimeout(() => {
            timers.delete(effect.id);
            onExpiry(sessionId);
        }, Math.max(0, effect.expiresAt! - now + 25)));
    }
}

/** Drops tracker entries with no sockets that have been idle past the grace period. */
export function cleanupStaleSessions(now: number): void {
    sessionTracker.forEach((tracker, sessionId) => {
        if (tracker.socketIds.size > 0 || now - tracker.lastSeen <= SESSION_CONFIG.gracePeriodMs)
            return;

        logger.debug(`[SOCKET:${formatSessionId(sessionId)}] \x1b[34mCleaning up stale session\x1b[0m`);
        tracker.expiryTimers?.forEach(timer => clearTimeout(timer));
        tracker.expiryTimers?.clear();
        sessionTracker.delete(sessionId);
    });
}
