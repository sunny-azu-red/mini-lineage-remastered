import type { Server as SocketIOServer, Socket } from 'socket.io';
import type { z } from 'zod';
import type { Ack } from '@shared/contract';
import type { PlayerState } from '@/interface';
import type { Guard } from './guard';
import type { RateLimiter } from './rate-limit';
import type { SessionContext } from './session';
import { withSession, readSession } from './session';
import { floodLimiter } from './rate-limit';
import { SocketError, toAckError } from './error';
import { emitStateUpdate } from './emitter';
import { refreshExpiryTimers } from './tick';
import { buildPlayerSnapshot } from './serializer/player.serializer';
import { logger } from '@/config/logger.config';
import { formatSessionId } from '@/util/format.util';
import { isRelease } from '@/util/version.util';
import { GAME_VERSION } from '@/constant/game.constant';

/**
 * Declarative shape every socket event handler plugs into — Zod validation, guards,
 * rate limiting, locking, and acking are all handled once by registerEvent() below.
 */
export interface EventDefinition<TIn, TOut> {
    event: string;
    schema: z.ZodType<TIn>;
    mode: 'read' | 'mutate';
    guards?: Guard[];
    rateLimit?: RateLimiter;
    handler: (ctx: SessionContext, payload: TIn) => TOut | Promise<TOut>;
}

type AckFn = (response: Ack<unknown>) => void;

/**
 * Socket.IO always passes the ack callback (if the caller provided one) as the LAST
 * argument. `input` never sends one; other events always do. Normalize both shapes here.
 */
function extractArgs(args: unknown[]): { payload: unknown; ack: AckFn | undefined } {
    if (args.length > 0 && typeof args[args.length - 1] === 'function') {
        const ack = args[args.length - 1] as AckFn;
        const payload = args.length > 1 ? args[0] : undefined;

        return { payload, ack };
    }

    return { payload: args[0], ack: undefined };
}

/**
 * Registers one client->server event on a socket: resolves the session id, applies the
 * flood limiter then (optionally) a per-event rate limiter, validates the payload with
 * Zod, runs guards against the current player inside withSession/readSession, calls the
 * handler, syncs other tabs on a mutation, and acks the result — or acks a mapped error
 * at any failure point. If the caller sent no ack (e.g. `input`), the result/error is
 * simply swallowed after being logged (toAckError already logs unexpected errors).
 */
export function registerEvent<TIn, TOut>(io: SocketIOServer, socket: Socket, def: EventDefinition<TIn, TOut>): void {
    socket.on(def.event, async (...args: unknown[]) => {
        const start = Date.now();
        const { payload, ack } = extractArgs(args);
        const req = socket.request as any;
        const sessionId: string | undefined = req.session?.id;
        const shortSid = formatSessionId(sessionId);

        const logResult = (ok: boolean) => {
            if (isRelease(GAME_VERSION))
                return;

            const duration = Date.now() - start;
            logger.debug(`[SOCKET:${shortSid}] \x1b[35m${def.event} = ${ok ? 'ok' : 'error'} (${duration}ms)\x1b[0m`);
        };

        try {
            if (!sessionId)
                throw new SocketError('UNAUTHENTICATED', 'Not authenticated.');

            const flood = floodLimiter.consume(sessionId);
            if (!flood.allowed)
                throw new SocketError('RATE_LIMITED', 'Too many requests. Please slow down.', flood.retryAfterMs);

            if (def.rateLimit) {
                const limited = def.rateLimit.consume(sessionId);
                if (!limited.allowed)
                    throw new SocketError('RATE_LIMITED', 'Too many requests. Please slow down.', limited.retryAfterMs);
            }

            const parsed = def.schema.safeParse(payload);
            if (!parsed.success) {
                const message = parsed.error.issues.map(i => i.message).join(', ') || 'Invalid payload.';
                throw new SocketError('INVALID_PAYLOAD', `Invalid payload: ${message}`);
            }

            let mutatedPlayer: PlayerState | undefined;
            const run = async (ctx: SessionContext): Promise<TOut> => {
                for (const guard of def.guards ?? [])
                    guard(ctx.player);

                const result = await def.handler(ctx, parsed.data);
                mutatedPlayer = ctx.player;

                return result;
            };

            const data = def.mode === 'mutate'
                ? await withSession(sessionId, run)
                : await readSession(sessionId, run);

            // Sync OTHER tabs on the same session — the acting socket gets its own full
            // result via the ack; a little redundancy for the acting tab is harmless and
            // matches today's multi-tab behavior where every tab receives the same push.
            if (def.mode === 'mutate' && mutatedPlayer) {
                emitStateUpdate(io, sessionId, buildPlayerSnapshot(mutatedPlayer));

                // Reschedule exact expiry timers (buffs/debuffs and the linger-driven
                // combat aura) right after this mutation persisted — without this, a
                // freshly-set expiresAt (e.g. battle:fight bumping lastFightAt) would sit
                // unscheduled until the next periodic tick or reconnect happened to catch
                // up, instead of firing at the exact millisecond it should.
                refreshExpiryTimers(io, sessionId, mutatedPlayer);
            }

            ack?.({ ok: true, data });
            logResult(true);
        } catch (err) {
            ack?.(toAckError(err));
            logResult(false);
        }
    });
}
