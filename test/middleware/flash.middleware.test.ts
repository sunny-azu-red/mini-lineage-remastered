import { describe, it, expect, vi } from 'vitest';
import { flashMiddleware } from '@/middleware/flash.middleware';
import { FlashMessage } from '@/interface';

describe('flashMiddleware', () => {
    it('should populate res.locals.flash from session and delete it', () => {
        const flash: FlashMessage = { text: 'test', type: 'info' };
        const req = { session: { flash } as any };
        const res = { locals: {} as any };
        const next = vi.fn();

        flashMiddleware(req as any, res as any, next);

        expect(res.locals.flash).toBe(flash);
        expect(req.session.flash).toBeUndefined();
        expect(next).toHaveBeenCalled();
    });

    it('should set res.locals.flash to null if not present in session', () => {
        const req = { session: {} as any };
        const res = { locals: {} as any };
        const next = vi.fn();

        flashMiddleware(req as any, res as any, next);

        expect(res.locals.flash).toBeNull();
        expect(next).toHaveBeenCalled();
    });
});
