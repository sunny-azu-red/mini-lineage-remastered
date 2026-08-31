import type { Server as SocketIOServer } from 'socket.io';
import type { ActiveEffect, SessionTrackerEntry, PlayerState } from '@/interface';
import { TICK_CONFIG } from '@/constant/game.constant';
import { processEffectExpiry, processRegenTick, isGameStarted, getPlayerStats } from '@/service/player.service';
import { withSession, NO_CHANGE } from './session';
import { buildPlayerSnapshot } from './serializer/player.serializer';
import { emitStateUpdate, syncExpiryTimers, cleanupStaleSessions, sessionTracker } from './emitter';
import { logger } from '@/config/logger.config';
import { capitalize, formatSessionId } from '@/util/format.util';

/**
 * Reschedules exact expiry timers for a session, wiring each firing back into an expiry-only
 * tick. Lives here rather than emitter.ts because it needs `processSessionTick`, and emitter.ts
 * must not import from tick.ts (tick.ts already imports from it). No-op without a tracker.
 */
export function refreshExpiryTimers(io: SocketIOServer, sessionId: string, player: PlayerState): void {
    const tracker = sessionTracker.get(sessionId);
    if (!tracker)
        return;

    syncExpiryTimers(io, tracker, sessionId, player, (expiredSessionId) => {
        const activeTracker = sessionTracker.get(expiredSessionId);
        if (activeTracker)
            void processSessionTick(io, activeTracker, expiredSessionId, 'expiry');
    });
}

/**
 * Which single job a firing performs. The periodic loop only ever regenerates; expiry is driven
 * exclusively by each effect's own exact timer.
 */
export type TickKind = 'regen' | 'expiry';

/**
 * One line per firing: `[TICK:<sid>] <Zone> | HP: <old> -> <new>/<max> (<status>)`.
 * `expiring` must be captured BEFORE the expiry sweep removes those effects.
 *
 * `changed` is the tick's own return value, deliberately NOT folded with `zoneChanged`: a
 * pure zone flip should fall through to Full/Paused/0 HPR/Idle, not claim "Effect Expired".
 */
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
 * Ticks one session. An uninitialized session, or a tick producing no change, is a silent
 * no-op. `ctx.zoneChanged` is folded into `changed` because neither job knows anything about
 * zones, so a zone-only flip must still persist and broadcast. Errors are logged, never thrown —
 * they must not crash the shared loop.
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

            const oldHp = ctx.player.health;
            const now = Date.now();
            const expiring = (ctx.player.effects ?? []).filter(e => e.expiresAt !== undefined && e.expiresAt <= now);

            // One job per firing. The periodic loop is the REGEN cadence and nothing else;
            // buffs, debuffs and auras expire on their own exact timers. Letting the loop sweep
            // effects too is what hid a lost timer as a mere 5-second delay instead of a fault.
            const tickChanged = kind === 'regen' ? processRegenTick(ctx.player) : processEffectExpiry(ctx.player);
            playerRef = ctx.player;

            logTickResult(sessionId, ctx.player, oldHp, expiring, tickChanged);

            return tickChanged || ctx.zoneChanged ? buildPlayerSnapshot(ctx.player) : NO_CHANGE;
        });

        if (!playerRef)
            return;

        // Before the NO_CHANGE check on purpose, so every tick re-derives the timers this session
        // should have. A tick that changes nothing is exactly when a missing timer needs
        // replacing — gating this on `snapshot` is what let one stale timer delay an expiry by a
        // full tick interval.
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
