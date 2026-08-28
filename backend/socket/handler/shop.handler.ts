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

const ITEM_TYPE_BY_PAYLOAD_TYPE: Record<'weapon' | 'armor' | 'food', ItemType> = {
    weapon: ItemType.Weapon,
    armor: ItemType.Armor,
    food: ItemType.Food,
};

/**
 * From shop.controller.ts. Plan decision A8: one unified `shop:purchase` event instead of
 * three separate weapon/armor/food events — one guard set, one rate limiter, maps 1:1 onto
 * the existing purchaseItem(player, ItemType, itemId) signature.
 */
export function registerShopHandlers(io: SocketIOServer, socket: Socket): void {
    registerEvent(io, socket, {
        event: 'shop:purchase',
        schema: ShopPurchasePayloadSchema,
        mode: 'mutate',
        guards: [requireStarted, requireAlive],
        rateLimit: shopLimiter,
        handler: (ctx, payload): MutationResult => {
            const itemType = ITEM_TYPE_BY_PAYLOAD_TYPE[payload.type];
            const sound: SoundName = payload.type === 'food' ? 'eat' : 'buy';

            const result = purchaseItem(ctx.player, itemType, payload.itemId);
            if (!result)
                throw new SocketError('INVALID_PAYLOAD', 'Unknown item.');

            // A11: "not enough Adena"/"already own this" are ok:true acks carrying a danger
            // flash, exactly like today's PurchaseResult{success:false,...} — not an error code.
            const flashMsg = makePurchaseFlash(result, sound);

            return {
                player: buildPlayerSnapshot(ctx.player),
                flash: { text: flashMsg.text, type: flashMsg.type, sound: flashMsg.sound as SoundName | undefined },
            };
        },
    });
}
