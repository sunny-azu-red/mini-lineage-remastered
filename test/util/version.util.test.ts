import { describe, it, expect, vi, afterEach } from 'vitest';
import * as fs from 'fs';
import { isRelease, getVersion } from '@/util/version.util';
import { env } from '@/config/env.config';

vi.mock('@/config/env.config', () => ({
    env: {
        NODE_ENV: 'development',
    }
}));

vi.mock('fs', async (importOriginal) => {
    const actual = await importOriginal<typeof import('fs')>();
    return {
        ...actual,
        existsSync: vi.fn(),
        readFileSync: vi.fn(),
    };
});

describe('version utility', () => {
    afterEach(() => {
        vi.restoreAllMocks();
        vi.mocked(env).NODE_ENV = 'development';
    });

    describe('isRelease', () => {
        describe('when NODE_ENV is production', () => {
            it('returns true regardless of the version string content', () => {
                vi.mocked(env).NODE_ENV = 'production';

                expect(isRelease('⚡ development')).toBe(true);
                expect(isRelease('anything')).toBe(true);
                expect(isRelease('')).toBe(true);
            });
        });

        describe('when NODE_ENV is NOT production', () => {
            it('returns true for a valid 7-char hex git hash', () => {
                vi.mocked(env).NODE_ENV = 'development';
                expect(isRelease('a1b2c3d')).toBe(true);
            });

            it('is case-insensitive for hex hashes', () => {
                vi.mocked(env).NODE_ENV = 'development';
                expect(isRelease('A1B2C3D')).toBe(true);
            });

            it('returns false for "⚡ development"', () => {
                vi.mocked(env).NODE_ENV = 'development';
                expect(isRelease('⚡ development')).toBe(false);
            });

            it('returns false for invalid hex strings or lengths', () => {
                vi.mocked(env).NODE_ENV = 'development';

                expect(isRelease('a1b2c3')).toBe(false);
                expect(isRelease('xyz1234')).toBe(false);
                expect(isRelease('')).toBe(false);
            });
        });
    });

    describe('getVersion', () => {
        it('returns ⚡ development if the version file is missing', () => {
            vi.mocked(fs.existsSync).mockReturnValue(false);
            expect(getVersion()).toBe('⚡ development');
        });

        it('returns the content of version.txt if it exists', () => {
            vi.mocked(fs.existsSync).mockReturnValue(true);
            vi.mocked(fs.readFileSync).mockReturnValue('abc1234');
            expect(getVersion()).toBe('abc1234');
        });

        it('returns ⚡ development if reading fails', () => {
            vi.mocked(fs.existsSync).mockReturnValue(true);
            vi.mocked(fs.readFileSync).mockImplementation(() => { throw new Error('fail'); });
            expect(getVersion()).toBe('⚡ development');
        });
    });
});
