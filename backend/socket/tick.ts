import type { Server as SocketIOServer } from 'socket.io';
import type { ActiveEffect, SessionTrackerEntry, PlayerState } from '@/interface';
import { TICK_CONFIG } from '@/constant/game.constant';
import { processRegenTick, isGameStarted, getPlayerStats } from '@/service/player.service';
import { withSession, NO_CHANGE } from './session';
import { buildPlayerSnapshot } from './serializer/player.serializer';
import { emitStateUpdate, scheduleNextExpiry, cleanupStaleSessions, sessionTracker } from './emitter';
import { logger } from '@/config/logger.config';
import { capitalize, formatSessionId } from '@/util/format.util';

/**
 * Re-arms the session's single expiry timer, wiring its firing back into an expiry-only tick.
 * Lives here (not emitter.ts) because emitter.ts must not import from tick.ts. No-op without a tracker.
 */
export function refreshExpiryTimers(io: SocketIOServer, sessionId: string, player: PlayerState): void {
    const tracker = sessionTracker.get(sessionId);
    if (!tracker)
        return;

    scheduleNextExpiry(tracker, sessionId, player, (expiredSessionId) => {
        const activeTracker = sessionTracker.get(expiredSessionId);
        if (activeTracker)
            void processSessionTick(io, activeTracker, expiredSessionId, 'expiry');
    });
}

// The periodic loop only ever regenerates; expiry is done by the session load itself (session.ts),
// and an 'expiry' firing exists purely to MAKE a load happen at the right moment.
export type TickKind = 'regen' | 'expiry';

/** One line per firing: `[TICK:<sid>] <Zone> | HP: <old> -> <new>/<max> (<status>)`. */
function logTickResult(sessionId: string, player: PlayerState, oldHp: number, expiring: ActiveEffect[], changed: boolean): void {
    const stats = getPlayerStats(player);
    const isDead = Boolean(player.dead || player.health <= 0);
    const inCombat = !isDead && Boolean(player.effects?.some(e => e.id === 'combat'));
    const zone = isDead ? 'Dead' : inCombat ? 'In Combat' : 'Resting';

    const hpDiff = player.health - oldHp;
    const hpDisplay = `${hpDiff !== 0 ? `${oldHp} -> ` : ''}${player.health}/${stats.maxHealth}`;

    const expiredLabel = expiring.map(e => e.label).join(', ');
    const expiredType = expiring.length > 0 ? capitalize(expiring[0].type) : 'Effect';
    const expiredSuffix = expiredLabel ? `: ${expiredLabel}` : '';

    let status: string;
    if (hpDiff > 0)
        status = `+${hpDiff} HPR`;
    else if (hpDiff < 0)
        status = `${hpDiff} HP | ${expiredType} Expired${expiredSuffix}`;
    else if (changed)
        status = expiredLabel ? `${expiredType} Expired${expiredSuffix}` : 'Effect Expired';
    else if (player.health >= stats.maxHealth)
        status = 'Full';
    else if (inCombat || isDead)
        status = 'Paused';
    else
        status = stats.regen === 0 ? '0 HPR' : 'Idle';

    logger.debug(`[TICK:${formatSessionId(sessionId)}] \x1b[34m${zone} | HP: ${hpDisplay} (${status})\x1b[0m`);
}

/**
 * Ticks one session; an uninitialized session or a no-op tick is silent. `ctx.zoneChanged` is
 * folded into `changed` since neither job knows about zones, so a zone-only flip must still
 * persist and broadcast. Errors are logged, never thrown — they must not crash the shared loop.
 */
export async function processSessionTick(
    io: SocketIOServer,
    tracker: SessionTrackerEntry,
    sessionId: string,
    kind: TickKind,
): Promise<void> {
    let playerRef: PlayerState | undefined;

    try {
        const snapshot = await withSession(sessionId, (ctx) => {
            if (!isGameStarted(ctx.player))
                return NO_CHANGE;

            // Expiry already happened in the session load; healthBefore predates its clamp so a
            // lapsed maxHealth buff still shows the HP drop.
            const oldHp = ctx.expiry.healthBefore ?? ctx.player.health;

            const tickChanged = kind === 'regen' ? processRegenTick(ctx.player) : false;
            playerRef = ctx.player;

            logTickResult(sessionId, ctx.player, oldHp, ctx.expiry.removed, tickChanged || ctx.expiry.changed);

            // ctx.expiry.changed belongs here too: when the load's sweep is the ONLY change, this
            // is the push that tells the client the effect (and its stats) went away.
            return tickChanged || ctx.zoneChanged || ctx.expiry.changed
                ? buildPlayerSnapshot(ctx.player)
                : NO_CHANGE;
        });

        if (!playerRef)
            return;

        // Before the NO_CHANGE check on purpose: a tick that changes nothing is exactly when a
        // missing timer needs replacing.
        refreshExpiryTimers(io, sessionId, playerRef);

        if (snapshot === undefined)
            return;

        emitStateUpdate(io, sessionId, snapshot);
    } catch (err) {
        logger.debug({ err }, `[TICK] session ${sessionId} tick skipped (session missing or errored)`);
    }
}

/** Prunes stale trackers, then ticks every session still tracked. */
export function startTickLoop(io: SocketIOServer): NodeJS.Timeout {
    return setInterval(() => {
        cleanupStaleSessions(Date.now());
        sessionTracker.forEach((tracker, sessionId) => {
            void processSessionTick(io, tracker, sessionId, 'regen');
        });
    }, TICK_CONFIG.intervalMs);
}
