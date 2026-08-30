import { z } from 'zod';
import type { ScreenId } from '@shared/contract';
import { RACES, CHARACTER_CONFIG, WEAPONS, ARMORS, FOODS } from '@/constant/game.constant';

const oneOf = (ids: readonly number[], message: string) =>
    z.number().int().refine(id => ids.includes(id), { message });

const RACE_IDS = RACES.map(r => r.id);
// slice(1) drops the starting item, which is never purchasable.
const WEAPON_IDS = WEAPONS.slice(1).map(w => w.id);
const ARMOR_IDS = ARMORS.slice(1).map(a => a.id);
const FOOD_IDS = FOODS.map(f => f.id);

export const SocketInputEventSchema = z.object({
    key: z.string().min(1).max(32),
});

export const GameStartPayloadSchema = z.object({
    raceId: oneOf(RACE_IDS, 'Invalid race selection'),
    name: z.string().trim().min(CHARACTER_CONFIG.nameMinLength).max(CHARACTER_CONFIG.nameMaxLength),
});

export const ShopPurchasePayloadSchema = z.discriminatedUnion('type', [
    z.object({ type: z.literal('weapon'), itemId: oneOf(WEAPON_IDS, 'Invalid weapon selection') }),
    z.object({ type: z.literal('armor'), itemId: oneOf(ARMOR_IDS, 'Invalid armor selection') }),
    z.object({ type: z.literal('food'), itemId: oneOf(FOOD_IDS, 'Invalid food selection') }),
]);

export const HighscoreListPayloadSchema = z.object({
    raceId: oneOf(RACE_IDS, 'Invalid race filter').optional().nullable(),
});

export const PlayerScreenPayloadSchema = z.object({
    // `satisfies` makes TypeScript reject any literal here that isn't a real ScreenId.
    screen: z.enum([
        'start', 'home', 'battle', 'weapons', 'armors', 'inn', 'suicide',
        'death', 'character', 'highscores', 'statistics', 'races', 'error',
    ] as const satisfies readonly ScreenId[]),
});

/** Accepts `{}` AND an omitted payload — Socket.IO sends no argument for `.emit(event, ack)`. */
export const EmptyPayloadSchema = z.object({}).strict().default({});

export type SocketInputEventPayload = z.infer<typeof SocketInputEventSchema>;
export type GameStartPayloadParsed = z.infer<typeof GameStartPayloadSchema>;
export type ShopPurchasePayloadParsed = z.infer<typeof ShopPurchasePayloadSchema>;
export type HighscoreListPayloadParsed = z.infer<typeof HighscoreListPayloadSchema>;
export type PlayerScreenPayloadParsed = z.infer<typeof PlayerScreenPayloadSchema>;
export type EmptyPayloadParsed = z.infer<typeof EmptyPayloadSchema>;
