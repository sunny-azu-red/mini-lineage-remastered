import type { Server as SocketIOServer } from 'socket.io';
import type { HydratePayload, PlayerSnapshot, FlashView } from '@shared/contract';
import type { SessionTrackerEntry, PlayerState } from '@/interface';
import { SESSION_CONFIG } from '@/constant/game.constant';
import { logger } from '@/config/logger.config';
import { formatSessionId } from '@/util/format.util';

/** Multi-tab session tracking + push-emission (see backend/socket/index.ts). */
export const sessionTracker = new Map<string, SessionTrackerEntry>();

export function trackSocket(_io: SocketIOServer, sessionId: string, socketId: string): void {
    let tracker = sessionTracker.get(sessionId);
    if (!tracker) {
        tracker = { socketIds: new Set(), lastSeen: Date.now() };
        sessionTracker.set(sessionId, tracker);
    }

    tracker.socketIds.add(socketId);
    tracker.lastSeen = Date.now();
}

export function untrackSocket(sessionId: string, socketId: string): void {
    const tracker = sessionTracker.get(sessionId);
    if (!tracker)
        return;

    tracker.socketIds.delete(socketId);
    tracker.lastSeen = Date.now();
}

function emitToTracked(io: SocketIOServer, sessionId: string, event: string, payload: unknown, excludeSocketId?: string): void {
    const tracker = sessionTracker.get(sessionId);
    if (!tracker)
        return;

    tracker.socketIds.forEach(socketId => {
        if (socketId === excludeSocketId)
            return;

        const targetSocket = io.sockets.sockets.get(socketId);
        if (targetSocket)
            targetSocket.emit(event, payload);
    });
}

export function emitHydrate(io: SocketIOServer, sessionId: string, payload: HydratePayload): void {
    emitToTracked(io, sessionId, 'hydrate', payload);
}

/**
 * `excludeSocketId`: the acting socket of a mutation already gets its own authoritative,
 * complete result via the request's own ack — it must NEVER also receive this push for the
 * same mutation. That "harmless redundancy" used to race the ack: the push has no
 * transition-detection logic of its own (e.g. "a reset just landed"), so if it arrived and
 * was applied first, it could silently clobber the baseline the ack's own handler needed,
 * leaving the UI stuck (see git history — the game:restart screen-freeze bug). Only OTHER
 * tabs on the same session should receive this.
 */
export function emitStateUpdate(io: SocketIOServer, sessionId: string, payload: Partial<PlayerSnapshot>, excludeSocketId?: string): void {
    emitToTracked(io, sessionId, 'state:update', payload, excludeSocketId);
}

export function emitNotice(io: SocketIOServer, sessionId: string, notice: FlashView): void {
    emitToTracked(io, sessionId, 'notice', notice);
}

/**
 * Synchronizes exact server-side timeouts for active timed effects on a session,
 * guaranteeing immediate tick execution and client sync at the exact millisecond of expiry.
 * `onExpiry` is invoked (with the sessionId) when a scheduled timer fires — the caller
 * (tick.ts's processSessionTick) is responsible for re-processing the session with
 * { applyRegen: false }. Taking the callback as a parameter (rather than importing
 * processSessionTick directly) avoids a circular import between emitter.ts and tick.ts.
 */
export function syncExpiryTimers(
    _io: SocketIOServer,
    tracker: SessionTrackerEntry,
    sessionId: string,
    player: PlayerState,
    onExpiry: (sessionId: string) => void,
): void {
    if (!tracker.expiryTimers)
        tracker.expiryTimers = new Map();

    const now = Date.now();
    const activeTimedEffects = (player.effects ?? []).filter(e => e.expiresAt && e.expiresAt > now);
    const activeEffectIds = new Set(activeTimedEffects.map(e => e.id));

    // Clear timers for effects that were removed or already expired
    for (const [id, timer] of tracker.expiryTimers.entries()) {
        if (!activeEffectIds.has(id)) {
            clearTimeout(timer);
            tracker.expiryTimers.delete(id);
        }
    }

    // Schedule exact timers for newly active timed effects
    for (const effect of activeTimedEffects) {
        if (effect.expiresAt && !tracker.expiryTimers.has(effect.id)) {
            const delayMs = Math.max(0, effect.expiresAt - now + 25);
            const timer = setTimeout(() => {
                tracker.expiryTimers?.delete(effect.id);
                onExpiry(sessionId);
            }, delayMs);
            tracker.expiryTimers.set(effect.id, timer);
        }
    }
}

/**
 * Grace-period cleanup — ported from the tail of today's global tick setInterval.
 * Removes tracker entries with no connected sockets that have been idle beyond
 * SESSION_CONFIG.gracePeriodMs, clearing any pending expiry timers first.
 */
export function cleanupStaleSessions(now: number): void {
    sessionTracker.forEach((tracker, sessionId) => {
        if (tracker.socketIds.size === 0 && now - tracker.lastSeen > SESSION_CONFIG.gracePeriodMs) {
            const sid = formatSessionId(sessionId);
            logger.debug(`[SOCKET:${sid}] \x1b[34mCleaning up stale session\x1b[0m`);

            if (tracker.expiryTimers) {
                for (const timer of tracker.expiryTimers.values())
                    clearTimeout(timer);

                tracker.expiryTimers.clear();
            }

            sessionTracker.delete(sessionId);
        }
    });
}
