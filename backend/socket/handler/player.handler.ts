import type { Server as SocketIOServer, Socket } from 'socket.io';
import type { MutationResult } from '@shared/contract';
import { registerEvent } from '../registry';
import { requireStarted, requireAlive } from '../guard';
import { EmptyPayloadSchema, PlayerScreenPayloadSchema } from '@/schema/socket.schema';
import { commitSuicide, syncZoneAuras } from '@/service/player.service';
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
        guards: [requireStarted, requireAlive],
        handler: (ctx): MutationResult => {
            commitSuicide(ctx.player);
            void statisticsRepository.increment('total_players_suicided');

            return { player: buildPlayerSnapshot(ctx.player), flash: null };
        },
    });

    /**
     * Fired by the client's navigate()/hydrate() (gameStore.ts) on every screen change — the
     * direct replacement for the old game's URL-path-based zone.middleware.ts, which recomputed
     * combat/resting zones synchronously on every page navigation. `requireAlive` is deliberately
     * NOT a guard here: a dead player is always pinned to 'death' client-side anyway, so recording
     * that is harmless, and syncZoneAuras already gives dead players neither aura regardless.
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
