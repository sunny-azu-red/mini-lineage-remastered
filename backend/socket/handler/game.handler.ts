import type { Server as SocketIOServer, Socket } from 'socket.io';
import type { MutationResult, HydratePayload, SoundName } from '@shared/contract';
import { registerEvent } from '../registry';
import { requireNotStarted, requireDead } from '../guard';
import { GameStartPayloadSchema, EmptyPayloadSchema } from '@/schema/socket.schema';
import { initializePlayer, resetPlayer, syncZoneAuras } from '@/service/player.service';
import { RACES } from '@/constant/game.constant';
import { buildPlayerSnapshot } from '../serializer/player.serializer';
import { buildGameCatalog } from '../serializer/catalog.serializer';

export function registerGameHandlers(io: SocketIOServer, socket: Socket): void {
    registerEvent(io, socket, {
        event: 'game:start',
        schema: GameStartPayloadSchema,
        mode: 'mutate',
        guards: [requireNotStarted],
        handler: (ctx, payload): MutationResult => {
            const flash = initializePlayer(ctx.player, RACES[payload.raceId], payload.name);

            // Stamped + synced here so a fresh character never renders auraless: withSession's
            // pre-mutation sync skipped this player (not started yet), and its post-mutation sync
            // runs too late for the snapshot returned below.
            ctx.player.currentScreen = 'home';
            syncZoneAuras(ctx.player);

            return {
                player: buildPlayerSnapshot(ctx.player),
                flash: { text: flash.text, type: flash.type, sound: flash.sound as SoundName | undefined },
            };
        },
    });

    registerEvent(io, socket, {
        event: 'game:restart',
        schema: EmptyPayloadSchema,
        mode: 'mutate',
        guards: [requireDead], // Only the fallen may start over.
        // Resets in place rather than destroying the session, which would desync this socket.
        handler: (ctx): { hydrate: HydratePayload } => {
            resetPlayer(ctx.player);

            return { hydrate: { player: buildPlayerSnapshot(ctx.player), catalog: buildGameCatalog() } };
        },
    });
}
