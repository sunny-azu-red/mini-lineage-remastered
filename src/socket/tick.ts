import type { Server as SocketIOServer } from 'socket.io';
import type { SessionTrackerEntry, PlayerState, TickOptions } from '@/interface';
import { TICK_CONFIG } from '@/constant/game.constant';
import { processTick, isGameStarted } from '@/service/player.service';
import { withSession, NO_CHANGE } from './session';
import { buildPlayerSnapshot } from './serializer/player.serializer';
import { emitStateUpdate, syncExpiryTimers, cleanupStaleSessions, sessionTracker } from './emitter';
import { logger } from '@/config/logger.config';

/**
 * Processes a single session's tick — rebuilt on withSession() (lock -> load -> mutate ->
 * persist -> release) in place of today's inline sessionStore.get/set + acquireSessionLock
 * duplication. `withSession` now runs `syncZoneAuras` automatically before this mutator
 * even starts (see session.ts), so this no longer calls it directly — but `ctx.zoneChanged`
 * still needs folding into `changed` here: `processTick` alone knows nothing about zones,
 * so a zone-only flip (e.g. the combat linger window expiring between ticks) must still
 * count as "something changed" or the resulting snapshot would silently stay stale.
 *
 * Mirrors today's `processSessionTick`: an uninitialized session, or a tick that produces
 * no change, is a silent no-op (no persist, no emit). A vanished session (SESSION_EXPIRED)
 * or any other error is caught and logged — it must never crash the shared tick loop.
 */
export async function processSessionTick(
    io: SocketIOServer,
    tracker: SessionTrackerEntry,
    sessionId: string,
    options: TickOptions = { applyRegen: true },
): Promise<void> {
    let playerRef: PlayerState | undefined;

    try {
        const snapshot = await withSession(sessionId, (ctx) => {
            if (!isGameStarted(ctx.player))
                return NO_CHANGE;

            const changed = processTick(ctx.player, options) || ctx.zoneChanged;
            playerRef = ctx.player;

            return changed ? buildPlayerSnapshot(ctx.player) : NO_CHANGE;
        });

        if (snapshot === undefined || !playerRef)
            return;

        syncExpiryTimers(io, tracker, sessionId, playerRef, (expiredSessionId) => {
            const activeTracker = sessionTracker.get(expiredSessionId);
            if (activeTracker)
                void processSessionTick(io, activeTracker, expiredSessionId, { applyRegen: false });
        });

        emitStateUpdate(io, sessionId, snapshot);
    } catch (err) {
        logger.debug({ err }, `[TICK] session ${sessionId} tick skipped (session missing or errored)`);
    }
}

/**
 * The shared periodic tick loop — replaces today's setInterval at the bottom of
 * initSocketService. First prunes tracker entries that have had no connected socket
 * for longer than the grace period, then ticks every session still tracked.
 */
export function startTickLoop(io: SocketIOServer): NodeJS.Timeout {
    return setInterval(() => {
        const now = Date.now();
        cleanupStaleSessions(now);

        sessionTracker.forEach((tracker, sessionId) => {
            void processSessionTick(io, tracker, sessionId, { applyRegen: true });
        });
    }, TICK_CONFIG.intervalMs);
}
