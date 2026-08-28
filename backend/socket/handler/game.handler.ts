import type { Server as SocketIOServer, Socket } from 'socket.io';
import type { MutationResult, HydratePayload, SoundName } from '@shared/contract';
import { registerEvent } from '../registry';
import { requireNotStarted } from '../guard';
import { GameStartPayloadSchema, EmptyPayloadSchema } from '@/schema/socket.schema';
import { initializePlayer, resetPlayer, syncZoneAuras } from '@/service/player.service';
import { RACES } from '@/constant/game.constant';
import { buildPlayerSnapshot } from '../serializer/player.serializer';
import { buildGameCatalog } from '../serializer/catalog.serializer';

/**
 * From game.controller.ts's postGameStart and player.controller.ts's getRestart.
 */
export function registerGameHandlers(io: SocketIOServer, socket: Socket): void {
    registerEvent(io, socket, {
        event: 'game:start',
        schema: GameStartPayloadSchema,
        mode: 'mutate',
        guards: [requireNotStarted],
        handler: (ctx, payload): MutationResult => {
            const race = RACES[payload.raceId];
            const flash = initializePlayer(ctx.player, race, payload.name);

            // A fresh character always lands on Home (GameStartScreen navigates there on
            // success) — stamped directly here, same reasoning as battle:fight's currentScreen
            // stamp: the client's own separate player:screen call for that navigation is a
            // second, independent round trip that could land after this ack, otherwise briefly
            // leaving a freshly-started character with no zone aura at all.
            ctx.player.currentScreen = 'home';

            // withSession's automatic pre-mutation sync ran before this handler started,
            // while isGameStarted(ctx.player) was still false, so it skipped entirely — its
            // post-mutation sync (after this handler returns) WOULD catch it, but that's too
            // late for the snapshot built below, which is what the acting client's ack sees
            // immediately. Sync here so a freshly-started character shows its resting aura
            // instantly, not after the next broadcast/tick.
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
        // No guard — works whether started or not, matching today's getRestart, which
        // destroys the session unconditionally. Per plan decision A9, reset in place
        // instead of session.destroy() (destroying mid-socket would desync the socket
        // from a dead session row).
        handler: (ctx): { hydrate: HydratePayload } => {
            resetPlayer(ctx.player);

            return {
                hydrate: { player: buildPlayerSnapshot(ctx.player), catalog: buildGameCatalog() },
            };
        },
    });
}
