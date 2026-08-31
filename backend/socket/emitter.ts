import type { Server as SocketIOServer } from 'socket.io';
import type { HydratePayload, PlayerSnapshot, FlashView } from '@shared/contract';
import type { SessionTrackerEntry, PlayerState } from '@/interface';
import { SESSION_CONFIG } from '@/constant/game.constant';

/** Fires just after the deadline, so the load-time sweep reliably sees the effect as due. */
const EXPIRY_GRACE_MS = 25;
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
 * Arms ONE timer for the session, at the earliest upcoming effect deadline, so a session load
 * happens the moment something is due — the load is what actually expires it (see
 * session.ts::loadContext). `onExpiry` is a parameter rather than a direct import purely to avoid
 * an emitter <-> tick cycle.
 *
 * Always cleared and re-armed from scratch. That is the whole point: the previous design kept a
 * timer per effect id and had to decide which existing timers still applied, which is where every
 * bug lived — an id-keyed check that missed a moved deadline, then a narrowed list that deleted
 * still-pending timers. A single earliest-deadline timer has no such decision to get wrong, and a
 * clearTimeout/setTimeout pair per call costs nothing.
 */
export function scheduleNextExpiry(
    tracker: SessionTrackerEntry,
    sessionId: string,
    player: PlayerState,
    onExpiry: (sessionId: string) => void,
): void {
    clearTimeout(tracker.expiryTimer);
    tracker.expiryTimer = undefined;

    // Truthiness, not `!== undefined`: a falsy-but-present `expiresAt: 0` means "no expiry", not
    // "expired in 1970".
    const deadlines = (player.effects ?? []).map(e => e.expiresAt).filter((at): at is number => Boolean(at));
    if (deadlines.length === 0)
        return;

    tracker.expiryTimer = setTimeout(() => {
        tracker.expiryTimer = undefined;
        onExpiry(sessionId);
    // The grace puts the firing just past the deadline, so the load-time sweep definitely sees it
    // as due. `Math.max(0, …)` covers a deadline already in the past — after a restart, say — by
    // firing immediately rather than not at all.
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
