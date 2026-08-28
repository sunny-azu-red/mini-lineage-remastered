import { describe, it, expect, vi, beforeEach } from 'vitest';
import * as versionUtil from '@/util/version.util';
import path from 'path';

vi.mock('@/util/version.util', async (importOriginal) => {
    const actual = await importOriginal<typeof import('@/util/version.util')>();
    return {
        ...actual,
        isRelease: vi.fn(),
    };
});

describe('static.middleware', () => {
    beforeEach(() => {
        vi.resetModules();
        vi.clearAllMocks();
    });

    it('exports a valid static middleware function', async () => {
        const { staticMiddleware } = await import('@/middleware/static.middleware');
        expect(staticMiddleware).toBeDefined();
        expect(typeof staticMiddleware).toBe('function');
    });

    it('resolves production client dist path (dist/public, via ../../public from dist/backend/middleware)', async () => {
        // Compiled output lands at dist/backend/middleware/static.middleware.js, so the release-mode
        // path climbs two directories to land on dist/public — the same directory Vite's build
        // (frontend/vite.config.ts, outDir '../dist/public') writes to.
        vi.mocked(versionUtil.isRelease).mockReturnValue(true);
        const { getClientDistPath } = await import('@/middleware/static.middleware');
        const resolvedPath = getClientDistPath();
        expect(resolvedPath).toContain('public');
        expect(resolvedPath).not.toContain(path.join('backend', 'public'));
        expect(resolvedPath).not.toContain('dist');
    });

    it('resolves development client dist path (dist/public, via ../../dist/public from backend/middleware)', async () => {
        vi.mocked(versionUtil.isRelease).mockReturnValue(false);
        const { getClientDistPath } = await import('@/middleware/static.middleware');
        const resolvedPath = getClientDistPath();
        expect(resolvedPath).toContain(path.join('dist', 'public'));
    });
});

describe('devFallbackMiddleware (Fix 3 — dev-mode replacement for static serving + SPA fallback)', () => {
    beforeEach(() => {
        vi.resetModules();
        vi.clearAllMocks();
    });

    function makeRes() {
        return {
            status: vi.fn().mockReturnThis(),
            send: vi.fn().mockReturnThis(),
        };
    }

    it('responds with a clear plain-text pointer to the Vite dev server for a non-API GET', async () => {
        const { devFallbackMiddleware } = await import('@/middleware/static.middleware');
        const req = { path: '/' } as any;
        const res = makeRes();
        const next = vi.fn();

        devFallbackMiddleware(req, res as any, next);

        expect(next).not.toHaveBeenCalled();
        expect(res.status).toHaveBeenCalledWith(200);
        expect(res.send).toHaveBeenCalledWith(expect.stringContaining('http://localhost:5173'));
    });

    it('responds for an arbitrary client-side route too (does not try to sendFile anything, unlike the production SPA fallback)', async () => {
        const { devFallbackMiddleware } = await import('@/middleware/static.middleware');
        const req = { path: '/battle' } as any;
        const res = makeRes();
        const next = vi.fn();

        devFallbackMiddleware(req, res as any, next);

        expect(res.status).toHaveBeenCalledWith(200);
        expect(res.send).toHaveBeenCalled();
        expect(next).not.toHaveBeenCalled();
    });

    it('lets /api/* requests fall through via next(), unhandled', async () => {
        const { devFallbackMiddleware } = await import('@/middleware/static.middleware');
        const req = { path: '/api/bootstrap' } as any;
        const res = makeRes();
        const next = vi.fn();

        devFallbackMiddleware(req, res as any, next);

        expect(next).toHaveBeenCalledTimes(1);
        expect(res.status).not.toHaveBeenCalled();
        expect(res.send).not.toHaveBeenCalled();
    });

    it('lets Socket.IO transport requests fall through via next(), unhandled (Vite proxies /socket.io here)', async () => {
        const { devFallbackMiddleware } = await import('@/middleware/static.middleware');
        const req = { path: '/socket.io/' } as any;
        const res = makeRes();
        const next = vi.fn();

        devFallbackMiddleware(req, res as any, next);

        expect(next).toHaveBeenCalledTimes(1);
        expect(res.status).not.toHaveBeenCalled();
    });
});
