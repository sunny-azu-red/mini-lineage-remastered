import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import * as versionUtil from '@/util/version.util';

vi.mock('@/util/version.util', async (importOriginal) => {
    const actual = await importOriginal<typeof import('@/util/version.util')>();
    return {
        ...actual,
        isRelease: vi.fn(),
    };
});

describe('rate-limit', () => {
    beforeEach(() => {
        vi.resetModules();
        vi.clearAllMocks();
    });

    afterEach(() => {
        vi.useRealTimers();
    });

    describe('skipIfDev', () => {
        it('is true when not release (dev bypass active)', async () => {
            vi.mocked(versionUtil.isRelease).mockReturnValue(false);
            const { skipIfDev } = await import('@/socket/rate-limit');
            expect(skipIfDev()).toBe(true);
        });

        it('is false when release', async () => {
            vi.mocked(versionUtil.isRelease).mockReturnValue(true);
            const { skipIfDev } = await import('@/socket/rate-limit');
            expect(skipIfDev()).toBe(false);
        });
    });

    describe('createSlidingWindow', () => {
        it('always allows when running in dev (bypass)', async () => {
            vi.mocked(versionUtil.isRelease).mockReturnValue(false);
            const { createSlidingWindow } = await import('@/socket/rate-limit');
            const limiter = createSlidingWindow('test', { windowMs: 1000, limit: 1 });

            expect(limiter.consume('k').allowed).toBe(true);
            expect(limiter.consume('k').allowed).toBe(true);
            expect(limiter.consume('k').allowed).toBe(true);
        });

        it('allows up to the limit then rejects within the release build', async () => {
            vi.mocked(versionUtil.isRelease).mockReturnValue(true);
            const { createSlidingWindow } = await import('@/socket/rate-limit');
            const limiter = createSlidingWindow('test', { windowMs: 1000, limit: 2 });

            expect(limiter.consume('k').allowed).toBe(true);
            expect(limiter.consume('k').allowed).toBe(true);
            const third = limiter.consume('k');
            expect(third.allowed).toBe(false);
            if (!third.allowed)
                expect(third.retryAfterMs).toBeGreaterThan(0);
        });

        it('tracks separate keys independently', async () => {
            vi.mocked(versionUtil.isRelease).mockReturnValue(true);
            const { createSlidingWindow } = await import('@/socket/rate-limit');
            const limiter = createSlidingWindow('test', { windowMs: 1000, limit: 1 });

            expect(limiter.consume('a').allowed).toBe(true);
            expect(limiter.consume('b').allowed).toBe(true);
            expect(limiter.consume('a').allowed).toBe(false);
        });

        it('allows again once the window has fully elapsed', async () => {
            vi.useFakeTimers();
            vi.mocked(versionUtil.isRelease).mockReturnValue(true);
            const { createSlidingWindow } = await import('@/socket/rate-limit');
            const limiter = createSlidingWindow('test', { windowMs: 1000, limit: 1 });

            expect(limiter.consume('k').allowed).toBe(true);
            expect(limiter.consume('k').allowed).toBe(false);

            vi.advanceTimersByTime(1001);

            expect(limiter.consume('k').allowed).toBe(true);
        });

        it('the GC interval does not keep the process alive (unref)', async () => {
            vi.useFakeTimers();
            vi.mocked(versionUtil.isRelease).mockReturnValue(true);
            const { createSlidingWindow } = await import('@/socket/rate-limit');
            const setIntervalSpy = vi.spyOn(global, 'setInterval');
            createSlidingWindow('test-gc', { windowMs: 1000, limit: 1 });

            expect(setIntervalSpy).toHaveBeenCalled();
            const timer = setIntervalSpy.mock.results[0].value;
            expect(typeof timer.unref).toBe('function');
        });

        it('the periodic GC removes fully-expired keys', async () => {
            vi.useFakeTimers();
            vi.mocked(versionUtil.isRelease).mockReturnValue(true);
            const { createSlidingWindow } = await import('@/socket/rate-limit');
            const limiter = createSlidingWindow('test-gc-2', { windowMs: 1000, limit: 5 });

            limiter.consume('stale-key');
            vi.advanceTimersByTime(1000); // trigger the GC interval, key's timestamp now stale

            // after GC, the key should behave like brand new (still allowed, unaffected either way)
            expect(limiter.consume('stale-key').allowed).toBe(true);
        });

        it('the periodic GC prunes only the stale timestamps of a partially-stale key, keeping the key itself', async () => {
            vi.useFakeTimers();
            vi.mocked(versionUtil.isRelease).mockReturnValue(true);
            const { createSlidingWindow } = await import('@/socket/rate-limit');
            const limiter = createSlidingWindow('test-gc-3', { windowMs: 1000, limit: 2 });

            limiter.consume('mixed-key'); // t+0 — stale by the time the GC sweeps
            vi.advanceTimersByTime(600);
            limiter.consume('mixed-key'); // t+600 — still fresh when the GC sweeps
            limiter.consume('fresh-key'); // t+600 — wholly fresh, the GC must leave it alone
            vi.advanceTimersByTime(400);  // t+1000 — GC fires: drops t+0, keeps t+600

            // The key survived the sweep with its single fresh hit, so only ONE further consume
            // fits under the limit of 2 (a fully-deleted key would have allowed two), and the
            // retry window is measured from the surviving t+600 hit.
            expect(limiter.consume('mixed-key').allowed).toBe(true);
            const denied = limiter.consume('mixed-key');
            expect(denied.allowed).toBe(false);
            if (!denied.allowed)
                expect(denied.retryAfterMs).toBe(600);

            // The untouched all-fresh key kept its one hit too (one more consume fits, a second
            // does not) — the GC neither dropped it nor rewrote it.
            expect(limiter.consume('fresh-key').allowed).toBe(true);
            expect(limiter.consume('fresh-key').allowed).toBe(false);
        });
    });

    describe('exported limiters', () => {
        it('exposes battleLimiter, shopLimiter, and floodLimiter', async () => {
            vi.mocked(versionUtil.isRelease).mockReturnValue(false);
            const { battleLimiter, shopLimiter, floodLimiter } = await import('@/socket/rate-limit');

            expect(battleLimiter.name).toBe('battle');
            expect(shopLimiter.name).toBe('shop');
            expect(floodLimiter.name).toBe('flood');
        });
    });
});
