import { describe, it, expect, vi, beforeEach } from 'vitest';
import { skipIfDev, battleRateLimitHandler, shopRateLimitHandler } from './rate-limit.middleware';
import * as version from '@/util/version.util';
import * as rateLimitView from '@/view/rate-limit.view';

// mock the constant as it might be 'development' or a real SHA
vi.mock('@/constant/game.constant', async (importOriginal) => {
    const actual = await importOriginal<typeof import('@/constant/game.constant')>();
    return {
        ...actual,
        GAME_VERSION: 'development',
    };
});

vi.mock('@/view/rate-limit.view', () => ({
    renderRateLimitView: vi.fn().mockReturnValue('<html>Rate Limit</html>')
}));

describe('rate-limit.middleware', () => {
    beforeEach(() => {
        vi.clearAllMocks();
    });

    describe('skipIfDev', () => {
        it('should skip rate limiting when not in release mode', () => {
            const spy = vi.spyOn(version, 'isRelease').mockReturnValue(false);
            expect(skipIfDev()).toBe(true);
            spy.mockRestore();
        });

        it('should not skip rate limiting when in release mode', () => {
            const spy = vi.spyOn(version, 'isRelease').mockReturnValue(true);
            expect(skipIfDev()).toBe(false);
            spy.mockRestore();
        });
    });

    describe('handlers', () => {
        it('battleRateLimitHandler should render ambush message when player is ambushed', () => {
            const req = { originalUrl: '/battle' };
            const res = {
                status: vi.fn().mockReturnThis(),
                send: vi.fn(),
                locals: { player: { ambushed: true, dead: false } }
            };

            battleRateLimitHandler(req as any, res as any);

            expect(res.status).toHaveBeenCalledWith(429);
            expect(rateLimitView.renderRateLimitView).toHaveBeenCalledWith(
                res.locals.player,
                expect.stringContaining('ambush'),
                req.originalUrl
            );
        });

        it('battleRateLimitHandler should render standard message when player is not ambushed', () => {
            const req = { originalUrl: '/battle' };
            const res = {
                status: vi.fn().mockReturnThis(),
                send: vi.fn(),
                locals: { player: { ambushed: false, dead: false } }
            };

            battleRateLimitHandler(req as any, res as any);

            expect(rateLimitView.renderRateLimitView).toHaveBeenCalledWith(
                res.locals.player,
                expect.stringContaining('moving too fast'),
                req.originalUrl
            );
        });

        it('shopRateLimitHandler should render standard message', () => {
            const req = { originalUrl: '/shop/weapons' };
            const res = {
                status: vi.fn().mockReturnThis(),
                send: vi.fn(),
                locals: { player: { ambushed: false, dead: false } }
            };

            shopRateLimitHandler(req as any, res as any);

            expect(rateLimitView.renderRateLimitView).toHaveBeenCalledWith(
                res.locals.player,
                expect.stringContaining('moving too fast'),
                req.originalUrl
            );
        });
    });
});
