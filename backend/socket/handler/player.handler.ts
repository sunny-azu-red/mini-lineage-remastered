import type { Server as SocketIOServer, Socket } from 'socket.io';
import type { MutationResult } from '@shared/contract';
import { registerEvent } from '../registry';
import { requireStarted, requireAlive } from '../guard';
import { EmptyPayloadSchema, PlayerScreenPayloadSchema } from '@/schema/socket.schema';
import { commitSuicide, syncZoneAuras } from '@/service/player.service';
import { statisticsRepository } from '@/repository/statistics.repository';
import { buildPlayerSnapshot } from '../serializer/player.serializer';

export function registerPlayerHandlers(io: SocketIOServer, socket: Socket): void {
    // Deliberately no dedicated rate limiter (only the global flood limiter), matching the
    // original /suicide route.
    registerEvent(io, socket, {
        event: 'player:suicide',
        schema: EmptyPayloadSchema,
        mode: 'mutate',
        guards: [requireStarted, requireAlive],
        handler: (ctx): MutationResult => {
            commitSuicide(ctx.player);
            void statisticsRepository.increment('total_players_suicided');
            // Stamped here rather than left to a follow-up player:screen, same as game:start and
            // battle:fight do — the client now moves to the death screen in the same atomic store
            // update that applies this ack, so it never sends a separate navigation for it.
            ctx.player.currentScreen = 'death';

            return { player: buildPlayerSnapshot(ctx.player), flash: null };
        },
    });

    /**
     * Reports the client's current screen so syncZoneAuras can classify combat/resting from it.
     * `requireAlive` is intentionally absent: a dead player is pinned to 'death' client-side and
     * syncZoneAuras gives dead players no aura anyway, so recording it is harmless.
     */
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
