import { Server as HttpServer } from 'http';
import { Server as SocketIOServer, Socket } from 'socket.io';
import { RequestHandler } from 'express';
import { sessionStore } from '@/config/database.config';
import { acquireSessionLock } from '@/util/lock.util';
import { TICK_CONFIG, RACES, EFFECTS_CONFIG } from '@/constant/game.constant';
import { processTick, isGameStarted, getPlayerEffects, getPlayerStats, applyEffect } from '@/service/player.service';
import { PlayerState, TickOptions, SessionTrackerEntry } from '@/interface';
import { logger } from '@/config/logger.config';
import { z } from 'zod';
import { SocketInputEventSchema } from '@/schema/socket.schema';
import { statisticsRepository } from '@/repository/statistics.repository';
import { formatEffectTooltip, formatSessionId, capitalize } from '@/util/format.util';

const GRACE_PERIOD_MS = 10_000;
const SECRET_SEQUENCE = ['arrowup', 'arrowup', 'arrowdown', 'arrowdown', 'arrowleft', 'arrowright', 'arrowleft', 'arrowright', 'b', 'a'];

const sessionTracker = new Map<string, SessionTrackerEntry>();

let io: SocketIOServer;

/**
 * Synchronizes exact server-side timeouts for active timed effects on a session,
 * guaranteeing immediate tick execution and client sync at the exact millisecond of expiry.
 * Dispatches expiry ticks with { applyRegen: false } so natural HP regen is never awarded off-cadence.
 */
function syncExpiryTimers(tracker: SessionTrackerEntry, sessionId: string, player: PlayerState) {
    if (!tracker.expiryTimers) {
        tracker.expiryTimers = new Map();
    }
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
                processSessionTick(tracker, sessionId, { applyRegen: false });
            }, delayMs);
            tracker.expiryTimers.set(effect.id, timer);
        }
    }
}

/**
 * Builds the standardized player_update payload sent to connected clients.
 */
function buildPlayerUpdate(player: PlayerState) {
    const stats = isGameStarted(player) ? getPlayerStats(player) : null;
    const effects = getPlayerEffects(player).map(e => ({
        ...e,
        tooltip: formatEffectTooltip(e),
    }));
    return {
        health: player.health,
        maxHealth: stats ? stats.maxHealth : (player.raceId !== undefined ? RACES[player.raceId].startHealth : null),
        effects,
        stats: stats ? {
            attack: stats.attack,
            defense: stats.defense,
            crit: stats.crit,
            regen: stats.regen,
            ambush: stats.ambushRisk,
        } : null,
    };
}

/**
 * Emits a player_update event to all sockets tracked under a given session.
 */
function emitToSession(tracker: SessionTrackerEntry, player: PlayerState, sessionId?: string) {
    if (sessionId) {
        syncExpiryTimers(tracker, sessionId, player);
    }
    const payload = buildPlayerUpdate(player);

    tracker.socketIds.forEach(socketId => {
        const targetSocket = io.sockets.sockets.get(socketId);
        if (targetSocket)
            targetSocket.emit('player_update', payload);
    });
}

/**
 * Processes a single session's tick: loads the session, applies passive effects,
 * persists changes, and emits updates to connected clients.
 *
 * @param options.applyRegen Set to true during the 5s periodic regen tick, false during discrete effect expiry events.
 */
function processSessionTick(tracker: SessionTrackerEntry, sessionId: string, options: TickOptions = { applyRegen: true }) {
    acquireSessionLock(sessionId).then((release) => {
        sessionStore.get(sessionId, (err, session) => {
            if (err || !session) {
                release();
                return;
            }

            const player = session as unknown as PlayerState;
            if (!isGameStarted(player)) {
                release();
                return;
            }

            const sid = formatSessionId(sessionId);

            // process passive effects: buff/debuff expiry, health clamping, and optional natural regen
            const oldHp = player.health;
            const now = Date.now();
            const expiring = (player.effects || []).filter(e => e.expiresAt !== undefined && e.expiresAt <= now);
            const expiredLabel = expiring.map(e => e.label).join(', ');
            const changed = processTick(player, options);
            const stats = getPlayerStats(player);
            const isDead = Boolean(player.dead || player.health <= 0);
            const inCombat = !isDead && Boolean(player.effects?.some(e => e.id === 'combat'));
            const zone = isDead ? 'Dead' : (inCombat ? 'In Combat' : 'Resting');
            const hpDiff = player.health - oldHp;

            const hpDisplay = hpDiff !== 0
                ? `${oldHp} -> ${player.health}/${stats.maxHealth}`
                : `${player.health}/${stats.maxHealth}`;

            const typeStr = expiring.length > 0 ? capitalize(expiring[0].type) : 'Effect';

            let status: string;
            if (hpDiff > 0) {
                status = `+${hpDiff} HPR`;
            } else if (hpDiff < 0) {
                const labelStr = expiredLabel ? `: ${expiredLabel}` : '';
                status = `${hpDiff} HP | ${typeStr} Expired${labelStr}`;
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

            logger.debug(`[TICK:${sid}] \x1b[34m${zone} | HP: ${hpDisplay} (${status})\x1b[0m`);

            if (!changed) {
                release();
                return;
            }

            // persist the updated session and notify all connected clients
            sessionStore.set(sessionId, session, (saveErr) => {
                release();
                if (saveErr)
                    return;

                emitToSession(tracker, player, sessionId);
            });
        });
    });
}

export function initSocketService(server: HttpServer, sessionMiddleware: RequestHandler): void {
    io = new SocketIOServer(server, {
        cors: { origin: false },
    });

    io.use((socket, next) => {
        (sessionMiddleware as any)(socket.request, {}, next);
    });

    /**
     * Helper to securely register socket events with Zod validation.
     * Prevents malicious clients from bypassing HTTP validation by sending fake WebSocket events.
     */
    function registerSecureEvent<T>(
        socket: Socket,
        eventName: string,
        schema: z.ZodType<T>,
        handler: (data: T, sessionId: string) => void
    ) {
        socket.on(eventName, (payload) => {
            const parsed = schema.safeParse(payload);
            if (!parsed.success) {
                logger.warn({ err: parsed.error }, `[SOCKET] Invalid payload for event '${eventName}' from socket ${socket.id}`);
                return;
            }

            const req = socket.request as any;
            const sessionId: string | undefined = req.session?.id;

            if (!sessionId) {
                logger.warn(`[SOCKET] Unauthenticated event '${eventName}' from socket ${socket.id}`);
                return;
            }

            handler(parsed.data, sessionId);
        });
    }

    io.on('connection', (socket: Socket) => {
        const req = socket.request as any;
        const sessionId: string | undefined = req.session?.id;

        // sync state and track this socket for this session ID
        if (sessionId) {
            let tracker = sessionTracker.get(sessionId);
            if (!tracker) {
                tracker = { socketIds: new Set(), lastSeen: Date.now() };
                sessionTracker.set(sessionId, tracker);
            }

            tracker.socketIds.add(socket.id);
            tracker.lastSeen = Date.now();

            // initial update to sync state after page load (prevents stale UI)
            sessionStore.get(sessionId, (err, session) => {
                if (err || !session) return;
                const player = session as PlayerState;
                if (tracker) {
                    syncExpiryTimers(tracker, sessionId, player);
                }
                socket.emit('player_update', buildPlayerUpdate(player));
            });
        }

        socket.on('disconnect', () => {
            if (sessionId) {
                const tracker = sessionTracker.get(sessionId);
                if (tracker) {
                    tracker.socketIds.delete(socket.id);
                    tracker.lastSeen = Date.now();
                }
            }
        });

        // control key / sequence listener
        registerSecureEvent(socket, 'input', SocketInputEventSchema, (data, sid) => {
            const tracker = sessionTracker.get(sid);
            if (!tracker) return;

            if (!tracker.inputBuffer) tracker.inputBuffer = [];
            tracker.inputBuffer.push(data.key.toLowerCase());
            if (tracker.inputBuffer.length > SECRET_SEQUENCE.length) {
                tracker.inputBuffer.shift();
            }

            if (tracker.inputBuffer.length === SECRET_SEQUENCE.length &&
                tracker.inputBuffer.every((k, idx) => k === SECRET_SEQUENCE[idx])) {
                tracker.inputBuffer = [];

                acquireSessionLock(sid).then((release) => {
                    sessionStore.get(sid, (err, session) => {
                        if (err || !session) {
                            release();
                            return;
                        }

                        const player = session as unknown as PlayerState;
                        if (!isGameStarted(player) || player.dead) {
                            release();
                            return;
                        }

                        player.cheated = true;
                        player.coward = true;
                        applyEffect(player, EFFECTS_CONFIG.konamiCheat);
                        void statisticsRepository.increment('total_players_cheated');

                        sessionStore.set(sid, session, (saveErr) => {
                            release();
                            if (saveErr) return;

                            const activeTracker = sessionTracker.get(sid);
                            if (activeTracker) {
                                emitToSession(activeTracker, player, sid);
                            }
                        });
                    });
                });
            }
        });
    });

    // global tick — runs every TICK_CONFIG.intervalMs on the server for passive HP regen
    setInterval(() => {
        const now = Date.now();

        sessionTracker.forEach((tracker, sessionId) => {
            // clean up stale sessions (no sockets and beyond grace period)
            if (tracker.socketIds.size === 0 && now - tracker.lastSeen > GRACE_PERIOD_MS) {
                const sid = formatSessionId(sessionId);
                logger.debug(`[SOCKET:${sid}] \x1b[34mCleaning up stale session\x1b[0m`);
                if (tracker.expiryTimers) {
                    for (const timer of tracker.expiryTimers.values()) {
                        clearTimeout(timer);
                    }
                    tracker.expiryTimers.clear();
                }
                sessionTracker.delete(sessionId);
                return;
            }

            processSessionTick(tracker, sessionId, { applyRegen: true });
        });
    }, TICK_CONFIG.intervalMs);
}
