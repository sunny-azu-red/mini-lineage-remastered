import type { Server as SocketIOServer, Socket } from 'socket.io';
import type { MutationResult } from '@shared/contract';
import { registerEvent } from '../registry';
import { requireStarted, requireAlive } from '../guard';
import { EmptyPayloadSchema, PlayerScreenPayloadSchema } from '@/schema/socket.schema';
import { commitSuicide, syncZoneAuras } from '@/service/player.service';
import { statisticsRepository } from '@/repository/statistics.repository';
import { buildPlayerSnapshot } from '../serializer/player.serializer';

export function registerPlayerHandlers(io: SocketIOServer, socket: Socket): void {
    // No dedicated rate limiter (only the global flood limiter), matching the original /suicide route.
    registerEvent(io, socket, {
        event: 'player:suicide',
        schema: EmptyPayloadSchema,
        mode: 'mutate',
        guards: [requireStarted, requireAlive],
        handler: (ctx): MutationResult => {
            commitSuicide(ctx.player);
            void statisticsRepository.increment('total_players_suicided');
            // Stamped here, like game:start and battle:fight, so the client moves to the death
            // screen in the same atomic update that applies this ack.
            ctx.player.currentScreen = 'death';

            return { player: buildPlayerSnapshot(ctx.player), flash: null };
        },
    });

    // requireAlive is intentionally absent: a dead player is pinned to 'death' client-side, and
    // syncZoneAuras gives dead players no aura anyway, so recording their screen is harmless.
    registerEvent(io, socket, {
        event: 'player:screen',
        schema: PlayerScreenPayloadSchema,
        mode: 'mutate',
        guards: [requireStarted],
        handler: (ctx, payload): MutationResult => {
            ctx.player.currentScreen = payload.screen;
            syncZoneAuras(ctx.player);

            return { player: buildPlayerSnapshot(ctx.player), flash: null };
        },
    });
}
