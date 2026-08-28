import { describe, it, expect, vi, beforeEach } from 'vitest';
import { debugMiddleware } from '@/middleware/debug.middleware';
import { logger } from '@/config/logger.config';
import * as version from '@/util/version.util';

vi.mock('@/config/logger.config', () => ({
    logger: {
        debug: vi.fn()
    }
}));

describe('debugMiddleware', () => {
    beforeEach(() => {
        vi.clearAllMocks();
    });

    it('should call next and register finish listener', () => {
        const req = { method: 'GET', url: '/', sessionID: 'xyz' };
        const res = { on: vi.fn(), statusCode: 200 };
        const next = vi.fn();

        debugMiddleware(req as any, res as any, next);

        expect(next).toHaveBeenCalled();
        expect(res.on).toHaveBeenCalledWith('finish', expect.any(Function));
    });

    it('should log debug info on finish in development', () => {
        vi.spyOn(version, 'isRelease').mockReturnValue(false);
        const req = { method: 'GET', url: '/', sessionID: 'xyz', session: { name: 'Player' } };
        let finishHandler: Function = () => { };
        const res = {
            on: vi.fn((event, handler) => { if (event === 'finish') finishHandler = handler; }),
            statusCode: 200
        };
        const next = vi.fn();

        debugMiddleware(req as any, res as any, next);
        finishHandler();

        expect(logger.debug).toHaveBeenCalledOnce();
        expect(logger.debug).toHaveBeenCalledWith(
            expect.stringMatching(/\[GET:xyz\] \x1b\[35m\/ = 200 \(\d+ms\)\x1b\[0m\n\x1b\[90m\{"name":"Player"\}\x1b\[0m/)
        );
    });

    it('should log POST payload if present in request body', () => {
        vi.spyOn(version, 'isRelease').mockReturnValue(false);
        const req = {
            method: 'POST',
            url: '/inn',
            sessionID: 'xyz',
            body: { select_food: '3' },
            session: { name: 'Player' }
        };
        let finishHandler: Function = () => { };
        const res = {
            on: vi.fn((event, handler) => { if (event === 'finish') finishHandler = handler; }),
            statusCode: 302
        };
        const next = vi.fn();

        debugMiddleware(req as any, res as any, next);
        finishHandler();

        expect(logger.debug).toHaveBeenCalledWith(
            expect.stringMatching(/\[POST:xyz\] \x1b\[35m\/inn = 302 \(\d+ms\)\x1b\[0m \x1b\[33mPayload: \{"select_food":"3"\}\x1b\[0m\n\x1b\[90m\{"name":"Player"\}\x1b\[0m/)
        );
    });

    it('should NOT log debug info on finish in release', () => {
        vi.spyOn(version, 'isRelease').mockReturnValue(true);
        const req = { method: 'GET', url: '/', sessionID: 'xyz' };
        let finishHandler: Function = () => { };
        const res = {
            on: vi.fn((event, handler) => { if (event === 'finish') finishHandler = handler; }),
            statusCode: 200
        };
        const next = vi.fn();

        debugMiddleware(req as any, res as any, next);
        finishHandler();

        expect(logger.debug).not.toHaveBeenCalled();
    });

    it('should handle missing session during debug log', () => {
        vi.spyOn(version, 'isRelease').mockReturnValue(false);
        const req = { method: 'GET', url: '/' }; // No sessionID
        let finishHandler: Function = () => { };
        const res = {
            on: vi.fn((event, handler) => { if (event === 'finish') finishHandler = handler; }),
            statusCode: 200
        };
        const next = vi.fn();

        debugMiddleware(req as any, res as any, next);
        finishHandler();

        expect(logger.debug).toHaveBeenCalledWith(
            expect.stringMatching(/\[GET:-------\] \x1b\[35m\/ = 200 \(\d+ms\)\x1b\[0m$/)
        );
    });

    it('should handle empty session during debug log', () => {
        vi.spyOn(version, 'isRelease').mockReturnValue(false);
        const req = { method: 'GET', url: '/', sessionID: 'xyz', session: {} };
        let finishHandler: Function = () => { };
        const res = {
            on: vi.fn((event, handler) => { if (event === 'finish') finishHandler = handler; }),
            statusCode: 200
        };
        const next = vi.fn();

        debugMiddleware(req as any, res as any, next);
        finishHandler();

        expect(logger.debug).toHaveBeenCalledWith(
            expect.stringMatching(/\[GET:xyz\] \x1b\[35m\/ = 200 \(\d+ms\)\x1b\[0m$/)
        );
    });
});
