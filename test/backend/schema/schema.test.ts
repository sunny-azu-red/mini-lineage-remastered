import { describe, it, expect } from 'vitest';
import {
    SocketInputEventSchema,
    GameStartPayloadSchema,
    ShopPurchasePayloadSchema,
    HighscoreListPayloadSchema,
} from '@/schema/socket.schema';
import { RACES, WEAPONS, ARMORS, FOODS, CHARACTER_CONFIG } from '@/constant/game.constant';

// ---------------------------------------------------------------------------
// Socket schemas
//
// The form-encoded schemas that used to live here (itemIdSchema, ShopWeaponSchema,
// ShopArmorSchema, ShopFoodSchema, GameStartSchema, SuicideSchema, and the
// common.schema.ts helper backing them) were deleted along with the legacy
// Express+EJS routes/controllers that parsed urlencoded form bodies. Their
// id-whitelist logic now lives in backend/schema/socket.schema.ts, which validates
// real JSON payloads over the socket — see GameStartPayloadSchema,
// ShopPurchasePayloadSchema, HighscoreListPayloadSchema, EmptyPayloadSchema.
// ---------------------------------------------------------------------------

describe('SocketInputEventSchema', () => {
    it('accepts a valid key string', () => {
        const result = SocketInputEventSchema.safeParse({ key: 'arrowup' });
        expect(result.success).toBe(true);
    });
    it('rejects an empty key string', () => {
        expect(SocketInputEventSchema.safeParse({ key: '' }).success).toBe(false);
    });
    it('rejects an excessively long string', () => {
        expect(SocketInputEventSchema.safeParse({ key: 'a'.repeat(33) }).success).toBe(false);
    });
    it('rejects non-string values', () => {
        expect(SocketInputEventSchema.safeParse({ key: 123 }).success).toBe(false);
    });
});

// ---------------------------------------------------------------------------
// The id-whitelist `.refine()` predicates below are the direct replacements for the
// deleted form-encoded itemIdSchema/ShopWeaponSchema/ShopArmorSchema/ShopFoodSchema
// whitelists — each one must accept every real catalog id AND reject anything outside
// it (including the two non-purchasable starting items, which are deliberately sliced
// out of the shop whitelists in socket.schema.ts).
// ---------------------------------------------------------------------------

describe('GameStartPayloadSchema', () => {
    it('accepts every real race id with a valid name', () => {
        for (const race of RACES)
            expect(GameStartPayloadSchema.safeParse({ raceId: race.id, name: 'Hero' }).success).toBe(true);
    });

    it('rejects an out-of-range raceId', () => {
        const result = GameStartPayloadSchema.safeParse({ raceId: 99, name: 'Hero' });
        expect(result.success).toBe(false);
        if (!result.success)
            expect(result.error.issues[0].message).toBe('Invalid race selection');
    });

    it('rejects a negative raceId', () => {
        expect(GameStartPayloadSchema.safeParse({ raceId: -1, name: 'Hero' }).success).toBe(false);
    });

    it('rejects a non-integer raceId before the whitelist even runs', () => {
        expect(GameStartPayloadSchema.safeParse({ raceId: 0.5, name: 'Hero' }).success).toBe(false);
    });

    it('rejects a name outside the configured length bounds', () => {
        expect(GameStartPayloadSchema.safeParse({ raceId: RACES[0].id, name: '   ' }).success).toBe(false);
        expect(GameStartPayloadSchema.safeParse({
            raceId: RACES[0].id,
            name: 'a'.repeat(CHARACTER_CONFIG.nameMaxLength + 1),
        }).success).toBe(false);
    });
});

describe('ShopPurchasePayloadSchema', () => {
    it('accepts every purchasable weapon id', () => {
        for (const weapon of WEAPONS.slice(1))
            expect(ShopPurchasePayloadSchema.safeParse({ type: 'weapon', itemId: weapon.id }).success).toBe(true);
    });

    it('rejects weapon id 0 — the starting item is never purchasable', () => {
        const result = ShopPurchasePayloadSchema.safeParse({ type: 'weapon', itemId: 0 });
        expect(result.success).toBe(false);
        if (!result.success)
            expect(result.error.issues[0].message).toBe('Invalid weapon selection');
    });

    it('rejects an unknown weapon id', () => {
        expect(ShopPurchasePayloadSchema.safeParse({ type: 'weapon', itemId: 99 }).success).toBe(false);
    });

    it('accepts every purchasable armor id', () => {
        for (const armor of ARMORS.slice(1))
            expect(ShopPurchasePayloadSchema.safeParse({ type: 'armor', itemId: armor.id }).success).toBe(true);
    });

    it('rejects armor id 0 — the starting item is never purchasable', () => {
        const result = ShopPurchasePayloadSchema.safeParse({ type: 'armor', itemId: 0 });
        expect(result.success).toBe(false);
        if (!result.success)
            expect(result.error.issues[0].message).toBe('Invalid armor selection');
    });

    it('rejects an unknown armor id', () => {
        expect(ShopPurchasePayloadSchema.safeParse({ type: 'armor', itemId: 99 }).success).toBe(false);
    });

    it('accepts every food id (unlike weapons/armors, food has no starting item to exclude)', () => {
        for (const food of FOODS)
            expect(ShopPurchasePayloadSchema.safeParse({ type: 'food', itemId: food.id }).success).toBe(true);
    });

    it('rejects an unknown food id', () => {
        const result = ShopPurchasePayloadSchema.safeParse({ type: 'food', itemId: 99 });
        expect(result.success).toBe(false);
        if (!result.success)
            expect(result.error.issues[0].message).toBe('Invalid food selection');
    });

    it('rejects an unknown discriminator', () => {
        expect(ShopPurchasePayloadSchema.safeParse({ type: 'potion', itemId: 1 }).success).toBe(false);
    });
});

describe('HighscoreListPayloadSchema', () => {
    it('accepts every real race id as a filter', () => {
        for (const race of RACES)
            expect(HighscoreListPayloadSchema.safeParse({ raceId: race.id }).success).toBe(true);
    });

    it('accepts an omitted or null filter (the "all races" view)', () => {
        expect(HighscoreListPayloadSchema.safeParse({}).success).toBe(true);
        expect(HighscoreListPayloadSchema.safeParse({ raceId: null }).success).toBe(true);
        expect(HighscoreListPayloadSchema.safeParse({ raceId: undefined }).success).toBe(true);
    });

    it('rejects an out-of-range raceId filter', () => {
        const result = HighscoreListPayloadSchema.safeParse({ raceId: 99 });
        expect(result.success).toBe(false);
        if (!result.success)
            expect(result.error.issues[0].message).toBe('Invalid race filter');
    });
});
