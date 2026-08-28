import { describe, it, expect, vi, beforeEach } from 'vitest';
import * as versionUtil from '@/util/version.util';

vi.mock('@/util/version.util', async (importOriginal) => {
    const actual = await importOriginal<typeof import('@/util/version.util')>();
    return {
        ...actual,
        isRelease: vi.fn(),
    };
});

describe('logger.config', () => {
    beforeEach(() => {
        vi.resetModules();
        vi.clearAllMocks();
    });

    it('should use info level if isRelease is true', async () => {
        vi.mocked(versionUtil.isRelease).mockReturnValue(true);
        const { logger } = await import('@/config/logger.config');
        expect(logger.level).toBe('info');
    });

    it('should use debug level if isRelease is false', async () => {
        vi.mocked(versionUtil.isRelease).mockReturnValue(false);
        const { logger } = await import('@/config/logger.config');
        expect(logger.level).toBe('debug');
    });
});
