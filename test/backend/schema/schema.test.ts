import { describe, it, expect } from 'vitest';
import { SocketInputEventSchema } from '@/schema/socket.schema';

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
