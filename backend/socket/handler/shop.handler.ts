import type { Server as SocketIOServer, Socket } from 'socket.io';
import type { MutationResult, SoundName } from '@shared/contract';
import { registerEvent } from '../registry';
import { requireStarted, requireAlive } from '../guard';
import { shopLimiter } from '../rate-limit';
import { SocketError } from '../error';
import { ShopPurchasePayloadSchema } from '@/schema/socket.schema';
import { purchaseItem } from '@/service/player.service';
import { makePurchaseFlash } from '@/util/game.util';
import { ItemType } from '@/interface';
import { buildPlayerSnapshot } from '../serializer/player.serializer';

/** One unified purchase event for all three shops — one guard set, one limiter. */
export function registerShopHandlers(io: SocketIOServer, socket: Socket): void {
    registerEvent(io, socket, {
        event: 'shop:purchase',
        schema: ShopPurchasePayloadSchema,
        mode: 'mutate',
        guards: [requireStarted, requireAlive],
        rateLimit: shopLimiter,
        handler: (ctx, payload): MutationResult => {
            // ItemType is a string enum whose values ARE 'weapon'/'armor'/'food', so this cast is exact.
            const result = purchaseItem(ctx.player, payload.type as ItemType, payload.itemId);
            if (!result)
                throw new SocketError('INVALID_PAYLOAD', 'Unknown item.');

            // "Not enough Adena"/"already own this" are ok:true acks with a danger flash, not
            // error codes.
            const flash = makePurchaseFlash(result, payload.type === 'food' ? 'eat' : 'buy');

            return {
                player: buildPlayerSnapshot(ctx.player),
                flash: { text: flash.text, type: flash.type, sound: flash.sound as SoundName | undefined },
            };
        },
    });
}
