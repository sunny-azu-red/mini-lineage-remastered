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

/** The shape every socket event plugs into; validation/guards/limits/locking/acking happen once below. */
export interface EventDefinition<TIn, TOut> {
    event: string;
    schema: z.ZodType<TIn>;
    mode: 'read' | 'mutate';
    guards?: Guard[];
    rateLimit?: RateLimiter;
    handler: (ctx: SessionContext, payload: TIn) => TOut | Promise<TOut>;
}

type AckFn = (response: Ack<unknown>) => void;

// Socket.IO passes the ack (when the caller sent one) as the last argument; `input` sends none.
function extractArgs(args: unknown[]): { payload: unknown; ack: AckFn | undefined } {
    if (args.length > 0 && typeof args[args.length - 1] === 'function')
        return { payload: args.length > 1 ? args[0] : undefined, ack: args[args.length - 1] as AckFn };

    return { payload: args[0], ack: undefined };
}

export function registerEvent<TIn, TOut>(io: SocketIOServer, socket: Socket, def: EventDefinition<TIn, TOut>): void {
    socket.on(def.event, async (...args: unknown[]) => {
        const start = Date.now();
        const { payload, ack } = extractArgs(args);
        const sessionId: string | undefined = (socket.request as any).session?.id;

        const logResult = (ok: boolean) => {
            if (!isRelease(GAME_VERSION))
                logger.debug(`[SOCKET:${formatSessionId(sessionId)}] \x1b[35m${def.event} = ${ok ? 'ok' : 'error'} (${Date.now() - start}ms)\x1b[0m`);
        };

        // OTHER tabs only — the acting socket already has the result via its own ack, and a
        // racing push (no transition detection) could clobber the baseline that ack needs.
        const syncOtherTabs = (sid: string, player: PlayerState | undefined) => {
            if (def.mode !== 'mutate' || !player)
                return;

            emitStateUpdate(io, sid, buildPlayerSnapshot(player), socket.id);
            refreshExpiryTimers(io, sid, player);
        };

        try {
            if (!sessionId) {
                // WARN, not the DEBUG logResult below: a release build raises pino past debug.
                logger.warn(`[SOCKET] Unauthenticated event '${def.event}' from socket ${socket.id}`);
                throw new SocketError('UNAUTHENTICATED', 'Not authenticated.');
            }

            for (const limiter of [floodLimiter, def.rateLimit]) {
                const check = limiter?.consume(sessionId);
                if (check && !check.allowed)
                    throw new SocketError('RATE_LIMITED', 'Too many requests. Please slow down.', check.retryAfterMs);
            }

            const parsed = def.schema.safeParse(payload);
            if (!parsed.success) {
                logger.warn({ err: parsed.error }, `[SOCKET] Invalid payload for event '${def.event}' from socket ${socket.id}`);
                throw new SocketError('INVALID_PAYLOAD', `Invalid payload: ${parsed.error.issues.map(i => i.message).join(', ') || 'Invalid payload.'}`);
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

            syncOtherTabs(sessionId, mutatedPlayer);

            ack?.({ ok: true, data });
            logResult(true);
        } catch (err) {
            ack?.(toAckError(err));
            logResult(false);
        }
    });
}
