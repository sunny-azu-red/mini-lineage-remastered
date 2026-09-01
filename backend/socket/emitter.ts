import type { Server as SocketIOServer } from 'socket.io';
import type { HydratePayload, PlayerSnapshot, FlashView } from '@shared/contract';
import type { SessionTrackerEntry, PlayerState } from '@/interface';
import { SESSION_CONFIG } from '@/constant/game.constant';
import { logger } from '@/config/logger.config';
import { formatSessionId } from '@/util/format.util';

/** Fires just after the deadline, so the load-time sweep reliably sees the effect as due. */
const EXPIRY_GRACE_MS = 25;

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

/** `excludeSocketId` skips the acting socket — it already has the result via its own ack, and this
 *  push carries no transition detection, so it could otherwise clobber that ack's baseline. */
export function emitStateUpdate(io: SocketIOServer, sessionId: string, payload: Partial<PlayerSnapshot>, excludeSocketId?: string): void {
    emitToTracked(io, sessionId, 'state:update', payload, excludeSocketId);
}

export function emitNotice(io: SocketIOServer, sessionId: string, notice: FlashView): void {
    emitToTracked(io, sessionId, 'notice', notice);
}

/**
 * Arms ONE timer for the session at the earliest upcoming effect deadline, so a session load
 * happens the moment something is due — the load is what actually expires it (session.ts).
 * Always cleared and re-armed from scratch rather than tracked per effect id, so there is never a
 * question of which existing timer still applies.
 */
export function scheduleNextExpiry(
    tracker: SessionTrackerEntry,
    sessionId: string,
    player: PlayerState,
    onExpiry: (sessionId: string) => void,
): void {
    clearTimeout(tracker.expiryTimer);
    tracker.expiryTimer = undefined;

    // Truthiness, not `!== undefined`: a falsy `expiresAt: 0` means "no expiry", not "1970".
    const deadlines = (player.effects ?? []).map(e => e.expiresAt).filter((at): at is number => Boolean(at));
    if (deadlines.length === 0)
        return;

    tracker.expiryTimer = setTimeout(() => {
        tracker.expiryTimer = undefined;
        onExpiry(sessionId);
    // Math.max(0, …) covers a deadline already in the past (e.g. after a restart) by firing now.
    }, Math.max(0, Math.min(...deadlines) - Date.now() + EXPIRY_GRACE_MS));
}

/** Drops tracker entries with no sockets that have been idle past the grace period. */
export function cleanupStaleSessions(now: number): void {
    sessionTracker.forEach((tracker, sessionId) => {
        if (tracker.socketIds.size > 0 || now - tracker.lastSeen <= SESSION_CONFIG.gracePeriodMs)
            return;

        logger.debug(`[SOCKET:${formatSessionId(sessionId)}] \x1b[34mCleaning up stale session\x1b[0m`);
        clearTimeout(tracker.expiryTimer);
        sessionTracker.delete(sessionId);
    });
}
