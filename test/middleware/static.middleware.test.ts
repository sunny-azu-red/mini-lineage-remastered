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

    it('resolves production client dist path (dist/public, via ../../public from dist/src/middleware)', async () => {
        // Compiled output lands at dist/src/middleware/static.middleware.js, so the release-mode
        // path climbs two directories to land on dist/public — the same directory Vite's build
        // (client/vite.config.ts, outDir '../dist/public') writes to.
        vi.mocked(versionUtil.isRelease).mockReturnValue(true);
        const { getClientDistPath } = await import('@/middleware/static.middleware');
        const resolvedPath = getClientDistPath();
        expect(resolvedPath).toContain('public');
        expect(resolvedPath).not.toContain(path.join('src', 'public'));
        expect(resolvedPath).not.toContain('dist');
    });

    it('resolves development client dist path (dist/public, via ../../dist/public from src/middleware)', async () => {
        vi.mocked(versionUtil.isRelease).mockReturnValue(false);
        const { getClientDistPath } = await import('@/middleware/static.middleware');
        const resolvedPath = getClientDistPath();
        expect(resolvedPath).toContain(path.join('dist', 'public'));
    });
});
