import { describe, it, expect, vi } from 'vitest';
import { helmetMiddleware } from '@/middleware/helmet.middleware';
import { requestContext } from '@/context/request.context';

describe('helmet.middleware', () => {
    it('should export a valid middleware function', () => {
        expect(helmetMiddleware).toBeDefined();
        expect(typeof helmetMiddleware).toBe('function');
    });

    it('should set Content-Security-Policy header with nonce from requestContext', () => {
        const req = {} as any;
        const headers: Record<string, string> = {};
        const res = {
            setHeader: vi.fn((key: string, val: string) => {
                headers[key.toLowerCase()] = val;
            }),
            getHeader: vi.fn((key: string) => headers[key.toLowerCase()]),
            removeHeader: vi.fn((key: string) => {
                delete headers[key.toLowerCase()];
            }),
            locals: {},
        } as any;
        const next = vi.fn();

        requestContext.run({ cspNonce: 'test-nonce-123' }, () => {
            helmetMiddleware(req, res, next);
        });

        expect(next).toHaveBeenCalled();
        const csp = headers['content-security-policy'];
        expect(csp).toBeDefined();
        expect(csp).toContain("'nonce-test-nonce-123'");
    });

    it('should fallback to res.locals.cspNonce if requestContext is not set', () => {
        const req = {} as any;
        const headers: Record<string, string> = {};
        const res = {
            setHeader: vi.fn((key: string, val: string) => {
                headers[key.toLowerCase()] = val;
            }),
            getHeader: vi.fn((key: string) => headers[key.toLowerCase()]),
            removeHeader: vi.fn((key: string) => {
                delete headers[key.toLowerCase()];
            }),
            locals: { cspNonce: 'local-nonce-456' },
        } as any;
        const next = vi.fn();

        helmetMiddleware(req, res, next);

        expect(next).toHaveBeenCalled();
        const csp = headers['content-security-policy'];
        expect(csp).toBeDefined();
        expect(csp).toContain("'nonce-local-nonce-456'");
    });

    it('should handle empty nonce gracefully when none provided', () => {
        const req = {} as any;
        const headers: Record<string, string> = {};
        const res = {
            setHeader: vi.fn((key: string, val: string) => {
                headers[key.toLowerCase()] = val;
            }),
            getHeader: vi.fn((key: string) => headers[key.toLowerCase()]),
            removeHeader: vi.fn((key: string) => {
                delete headers[key.toLowerCase()];
            }),
            locals: {},
        } as any;
        const next = vi.fn();

        helmetMiddleware(req, res, next);

        expect(next).toHaveBeenCalled();
        const csp = headers['content-security-policy'];
        expect(csp).toBeDefined();
        expect(csp).toContain("'nonce-'");
    });
});
