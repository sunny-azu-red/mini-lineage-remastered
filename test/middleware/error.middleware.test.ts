import { describe, it, expect, vi, beforeEach } from 'vitest';
import { errorMiddleware } from '@/middleware/error.middleware';
import * as layoutView from '@/view/layout.view';
import * as version from '@/util/version.util';
import { logger } from '@/config/logger.config';

vi.mock('@/config/logger.config', () => ({
    logger: {
        error: vi.fn()
    }
}));

vi.mock('@/view/base.view', () => ({
    readTemplate: vi.fn().mockReturnValue({ content: '', filename: 'error.ejs' }),
    render: vi.fn().mockReturnValue('<html>Error</html>')
}));

vi.mock('@/view/layout.view', () => ({
    renderSimplePage: vi.fn().mockReturnValue('<html>Simple Error</html>')
}));

describe('errorMiddleware', () => {
    beforeEach(() => {
        vi.clearAllMocks();
    });
    it('should log error and return 500 response', () => {
        const err = new Error('Test error');
        const req = {};
        const res = {
            status: vi.fn().mockReturnThis(),
            send: vi.fn(),
            locals: { player: { name: 'Player' } }
        };
        const next = vi.fn();

        errorMiddleware(err, req as any, res as any, next);

        expect(res.status).toHaveBeenCalledWith(500);
        expect(res.send).toHaveBeenCalledWith('<html>Simple Error</html>');
        expect(layoutView.renderSimplePage).toHaveBeenCalledWith(
            expect.any(String),
            expect.any(String),
            null,
            res.locals.player
        );
    });

    it('should use error status and correct title for 404', async () => {
        const err = { message: 'Custom error', status: 404 };
        const req = {};
        const res = {
            status: vi.fn().mockReturnThis(),
            send: vi.fn(),
            locals: { player: { name: 'Player' } }
        };
        const next = vi.fn();

        errorMiddleware(err as any, req as any, res as any, next);

        expect(res.status).toHaveBeenCalledWith(404);
        expect(layoutView.renderSimplePage).toHaveBeenCalledWith(
            'Page not found',
            expect.any(String),
            null,
            res.locals.player
        );
        
        // Should NOT call logger.error for 404
        expect(logger.error).not.toHaveBeenCalled();
    });

    it('should use "Something went wrong" for non-404 errors and log 500s', () => {
        const err = new Error('Test error');
        const req = {};
        const res = {
            status: vi.fn().mockReturnThis(),
            send: vi.fn(),
            locals: { player: { name: 'Player' } }
        };
        const next = vi.fn();

        errorMiddleware(err, req as any, res as any, next);

        expect(layoutView.renderSimplePage).toHaveBeenCalledWith(
            'Something went wrong',
            expect.any(String),
            null,
            res.locals.player
        );
        expect(logger.error).toHaveBeenCalled();
    });

    it('should log other 5xx errors like 503', () => {
        const err = { message: 'Service Unavailable', status: 503 };
        const req = {};
        const res = {
            status: vi.fn().mockReturnThis(),
            send: vi.fn(),
            locals: { player: { name: 'Player' } }
        };
        const next = vi.fn();

        errorMiddleware(err as any, req as any, res as any, next);

        expect(res.status).toHaveBeenCalledWith(503);
        expect(logger.error).toHaveBeenCalled();
    });

    it('should NOT log other 4xx errors like 403', () => {
        const err = { message: 'Forbidden', status: 403 };
        const req = {};
        const res = {
            status: vi.fn().mockReturnThis(),
            send: vi.fn(),
            locals: { player: { name: 'Player' } }
        };
        const next = vi.fn();

        errorMiddleware(err as any, req as any, res as any, next);

        expect(res.status).toHaveBeenCalledWith(403);
        expect(logger.error).not.toHaveBeenCalled();
    });

    it('should hide error details in release mode', () => {
        vi.spyOn(version, 'isRelease').mockReturnValue(true);
        const err = new Error('Secret error');
        const req = {};
        const res = {
            status: vi.fn().mockReturnThis(),
            send: vi.fn(),
            locals: { player: { name: 'Player' } }
        };
        const next = vi.fn();

        errorMiddleware(err, req as any, res as any, next);

        expect(res.status).toHaveBeenCalledWith(500);
    });

    it('should handle non-Error objects correctly', () => {
        vi.spyOn(version, 'isRelease').mockReturnValue(false);
        const err = "String error";
        const req = {};
        const res = {
            status: vi.fn().mockReturnThis(),
            send: vi.fn(),
            locals: { player: { name: 'Player' } }
        };
        const next = vi.fn();

        errorMiddleware(err as any, req as any, res as any, next);
        expect(res.status).toHaveBeenCalledWith(500);
    });
});
