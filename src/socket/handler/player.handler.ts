import type { Server as SocketIOServer, Socket } from 'socket.io';
import type { MutationResult } from '@shared/contract';
import { registerEvent } from '../registry';
import { requireStarted, requireAlive, requireNotAmbushed } from '../guard';
import { EmptyPayloadSchema } from '@/schema/socket.schema';
import { commitSuicide } from '@/service/player.service';
import { statisticsRepository } from '@/repository/statistics.repository';
import { buildPlayerSnapshot } from '../serializer/player.serializer';

/**
 * From player.controller.ts's postSuicide. No dedicated rate limiter today (only the
 * flood limiter, applied to every event by registerEvent) — confirmed via game.route.ts,
 * where /suicide carries no rate-limit middleware, unlike /battle and the shop/inn routes.
 */
export function registerPlayerHandlers(io: SocketIOServer, socket: Socket): void {
    registerEvent(io, socket, {
        event: 'player:suicide',
        schema: EmptyPayloadSchema,
        mode: 'mutate',
        guards: [requireStarted, requireAlive, requireNotAmbushed],
        handler: (ctx): MutationResult => {
            commitSuicide(ctx.player);
            void statisticsRepository.increment('total_players_suicided');

            return { player: buildPlayerSnapshot(ctx.player), flash: null };
        },
    });
}
