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
        vi.mocked(versionUtil.isRelease).mockReturnValue(true);
        const { getStaticPath } = await import('@/middleware/static.middleware');
        const resolvedPath = getStaticPath();
        expect(resolvedPath).toContain(path.join('src', 'public'));
    });

    it('resolves development static path when isRelease is false', async () => {
        vi.mocked(versionUtil.isRelease).mockReturnValue(false);
        const { getStaticPath } = await import('@/middleware/static.middleware');
        const resolvedPath = getStaticPath();
        expect(resolvedPath).toContain('public');
    });
});
