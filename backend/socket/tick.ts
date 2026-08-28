import type { Server as SocketIOServer } from 'socket.io';
import type { ActiveEffect, SessionTrackerEntry, PlayerState, TickOptions } from '@/interface';
import { TICK_CONFIG } from '@/constant/game.constant';
import { processTick, isGameStarted, getPlayerStats } from '@/service/player.service';
import { withSession, NO_CHANGE } from './session';
import { buildPlayerSnapshot } from './serializer/player.serializer';
import { emitStateUpdate, syncExpiryTimers, cleanupStaleSessions, sessionTracker } from './emitter';
import { logger } from '@/config/logger.config';
import { capitalize, formatSessionId } from '@/util/format.util';

/**
 * Schedules exact expiry timers for a session's currently active timed effects (buffs,
 * debuffs, and now the linger-driven combat aura — see player.service.ts's syncZoneAuras)
 * and wires their eventual firing back into an expiry-only tick (`{ applyRegen: false }`).
 *
 * Single shared home for what used to be an inline closure duplicated in both the
 * connection handler (backend/socket/index.ts) and processSessionTick below — both already
 * called `syncExpiryTimers` with the exact same `onExpiry` callback. Lives here (rather
 * than emitter.ts) because it needs `processSessionTick` directly; emitter.ts must NOT
 * import from tick.ts, since tick.ts already imports `syncExpiryTimers`/`sessionTracker`
 * from emitter.ts — importing the other way would create a cycle. tick.ts importing
 * FROM registry.ts (or index.ts) is never needed, so registry.ts and index.ts are free
 * to import this function from tick.ts without introducing one either.
 *
 * A no-op when the session has no tracker (e.g. it was never connected via a socket, or
 * was already cleaned up) — mirrors the pre-existing inline call sites' own tracker guard.
 */
export function refreshExpiryTimers(io: SocketIOServer, sessionId: string, player: PlayerState): void {
    const tracker = sessionTracker.get(sessionId);
    if (!tracker)
        return;

    syncExpiryTimers(io, tracker, sessionId, player, (expiredSessionId) => {
        const activeTracker = sessionTracker.get(expiredSessionId);
        if (activeTracker)
            void processSessionTick(io, activeTracker, expiredSessionId, { applyRegen: false });
    });
}

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
/**
 * Ported directly from the old game's socket.service.ts tick logging — one line per firing
 * (periodic OR exact-expiry), format: `[TICK:<sid>] <Zone> | HP: <old> -> <new>/<max> (<status>)`.
 * `expiring` must be captured BEFORE `processTick` runs (it removes expired effects from the
 * array), so its label is still available for the status line.
 */
function logTickResult(sessionId: string, player: PlayerState, oldHp: number, expiring: ActiveEffect[], changed: boolean): void {
    const stats = getPlayerStats(player);
    const isDead = Boolean(player.dead || player.health <= 0);
    const inCombat = !isDead && Boolean(player.effects?.some(e => e.id === 'combat'));
    const zone = isDead ? 'Dead' : (inCombat ? 'In Combat' : 'Resting');
    const hpDiff = player.health - oldHp;
    const expiredLabel = expiring.map(e => e.label).join(', ');
    const typeStr = expiring.length > 0 ? capitalize(expiring[0].type) : 'Effect';

    const hpDisplay = hpDiff !== 0
        ? `${oldHp} -> ${player.health}/${stats.maxHealth}`
        : `${player.health}/${stats.maxHealth}`;

    let status: string;
    if (hpDiff > 0) {
        status = `+${hpDiff} HPR`;
    } else if (hpDiff < 0) {
        status = `${hpDiff} HP${expiredLabel ? ` | ${typeStr} Expired: ${expiredLabel}` : ''}`;
    } else if (changed && expiredLabel) {
        status = `${typeStr} Expired: ${expiredLabel}`;
    } else if (changed) {
        status = 'Effect Expired';
    } else if (player.health >= stats.maxHealth) {
        status = 'Full';
    } else if (inCombat || isDead) {
        status = 'Paused';
    } else if (stats.regen === 0) {
        status = '0 HPR';
    } else {
        status = 'Idle';
    }

    logger.debug(`[TICK:${formatSessionId(sessionId)}] \x1b[34m${zone} | HP: ${hpDisplay} (${status})\x1b[0m`);
}

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

            const oldHp = ctx.player.health;
            const now = Date.now();
            const expiring = (ctx.player.effects ?? []).filter(e => e.expiresAt !== undefined && e.expiresAt <= now);

            const changed = processTick(ctx.player, options) || ctx.zoneChanged;
            playerRef = ctx.player;

            logTickResult(sessionId, ctx.player, oldHp, expiring, changed);

            return changed ? buildPlayerSnapshot(ctx.player) : NO_CHANGE;
        });

        if (snapshot === undefined || !playerRef)
            return;

        refreshExpiryTimers(io, sessionId, playerRef);

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
