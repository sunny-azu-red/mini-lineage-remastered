import { describe, it, expect, vi } from 'vitest';
import { contextMiddleware } from '@/middleware/context.middleware';
import { requestContext } from '@/context/request.context';

describe('contextMiddleware', () => {
    it('should generate cspNonce and set it on res.locals and requestContext', () => {
        const req = {} as any;
        const res = { locals: {} as any };
        let capturedNonce: string | undefined;

        const next = vi.fn(() => {
            capturedNonce = requestContext.getStore()?.cspNonce;
        });

        contextMiddleware(req as any, res as any, next);

        expect(res.locals.cspNonce).toBeDefined();
        expect(typeof res.locals.cspNonce).toBe('string');
        expect(res.locals.cspNonce.length).toBeGreaterThan(0);
        expect(capturedNonce).toBe(res.locals.cspNonce);
        expect(next).toHaveBeenCalled();
    });
});
