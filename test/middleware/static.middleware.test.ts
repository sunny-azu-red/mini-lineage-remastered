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

    it('resolves production static path when isRelease is true', async () => {
        // Compiled output now lands at dist/src/middleware/static.middleware.js (one extra
        // level of nesting than the old flat dist/middleware layout), so the release-mode
        // path climbs an extra directory to still land on dist/public. Under this test's
        // uncompiled execution (src/middleware directly), that resolves to the real repo-root
        // public/ dir — NOT src/public, which was the old (now-incorrect) expectation.
        vi.mocked(versionUtil.isRelease).mockReturnValue(true);
        const { getStaticPath } = await import('@/middleware/static.middleware');
        const resolvedPath = getStaticPath();
        expect(resolvedPath).toContain('public');
        expect(resolvedPath).not.toContain(path.join('src', 'public'));
    });

    it('resolves development static path when isRelease is false', async () => {
        vi.mocked(versionUtil.isRelease).mockReturnValue(false);
        const { getStaticPath } = await import('@/middleware/static.middleware');
        const resolvedPath = getStaticPath();
        expect(resolvedPath).toContain('public');
    });
});
