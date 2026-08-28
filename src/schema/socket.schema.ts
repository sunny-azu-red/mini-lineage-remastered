import { z } from 'zod';
import { RACES, CHARACTER_CONFIG, WEAPONS, ARMORS, FOODS } from '@/constant/game.constant';

export const SocketInputEventSchema = z.object({
    key: z.string().min(1).max(32),
});

export type SocketInputEventPayload = z.infer<typeof SocketInputEventSchema>;

const RACE_IDS = RACES.map(r => r.id);
const WEAPON_IDS = WEAPONS.slice(1).map(w => w.id); // don't allow fists (starting item)
const ARMOR_IDS = ARMORS.slice(1).map(a => a.id); // don't allow tunic (starting item)
const FOOD_IDS = FOODS.map(f => f.id);

/**
 * Real JSON numbers over the socket, not form-string transforms like the legacy
 * schema helpers (itemIdSchema) — the payload is a proper JS object, not urlencoded form data.
 */
export const GameStartPayloadSchema = z.object({
    raceId: z.number().int().refine(id => RACE_IDS.includes(id), { message: 'Invalid race selection' }),
    name: z.string().trim().min(CHARACTER_CONFIG.nameMinLength).max(CHARACTER_CONFIG.nameMaxLength),
});

export type GameStartPayloadParsed = z.infer<typeof GameStartPayloadSchema>;

export const ShopPurchasePayloadSchema = z.discriminatedUnion('type', [
    z.object({ type: z.literal('weapon'), itemId: z.number().int().refine(id => WEAPON_IDS.includes(id), { message: 'Invalid weapon selection' }) }),
    z.object({ type: z.literal('armor'), itemId: z.number().int().refine(id => ARMOR_IDS.includes(id), { message: 'Invalid armor selection' }) }),
    z.object({ type: z.literal('food'), itemId: z.number().int().refine(id => FOOD_IDS.includes(id), { message: 'Invalid food selection' }) }),
]);

export type ShopPurchasePayloadParsed = z.infer<typeof ShopPurchasePayloadSchema>;

export const HighscoreListPayloadSchema = z.object({
    raceId: z.number().int().refine(id => RACE_IDS.includes(id), { message: 'Invalid race filter' }).optional().nullable(),
});

export type HighscoreListPayloadParsed = z.infer<typeof HighscoreListPayloadSchema>;

/**
 * Accepts `{}` cleanly AND an omitted/undefined payload (Socket.IO delivers no payload
 * argument at all when the client calls `.emit(event, ack)` with no data — registerEvent's
 * arg-normalization surfaces that as `undefined`) — for events that carry no meaningful data.
 */
export const EmptyPayloadSchema = z.object({}).strict().default({});

export type EmptyPayloadParsed = z.infer<typeof EmptyPayloadSchema>;
