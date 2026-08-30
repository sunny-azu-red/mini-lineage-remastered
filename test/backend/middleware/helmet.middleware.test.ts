import { describe, it, expect, vi } from 'vitest';
import { helmetMiddleware } from '@/middleware/helmet.middleware';

describe('helmet.middleware', () => {
    it('should export a valid middleware function', () => {
        expect(helmetMiddleware).toBeDefined();
        expect(typeof helmetMiddleware).toBe('function');
    });

    it("should set a plain 'self' script-src with no nonce (no inline scripts remain)", () => {
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
        expect(csp).toContain("script-src 'self'");
        expect(csp).not.toContain('nonce-');
    });

    it("should allow ws:/wss: in connect-src for the Socket.IO upgrade", () => {
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

        const csp = headers['content-security-policy'];
        expect(csp).toBeDefined();
        expect(csp).toContain("connect-src 'self' ws: wss:");
    });
});
