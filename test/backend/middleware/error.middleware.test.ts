import { describe, it, expect, vi, beforeEach } from 'vitest';
import { errorMiddleware } from '@/middleware/error.middleware';
import * as version from '@/util/version.util';
import { logger } from '@/config/logger.config';

vi.mock('@/config/logger.config', () => ({
    logger: {
        error: vi.fn()
    }
}));

function makeRes() {
    return {
        status: vi.fn().mockReturnThis(),
        json: vi.fn(),
    };
}

describe('errorMiddleware', () => {
    beforeEach(() => {
        vi.clearAllMocks();
        vi.spyOn(version, 'isRelease').mockReturnValue(false);
    });

    it('should log error and return a JSON 500 response with the error message in dev', () => {
        const err = new Error('Test error');
        const req = {};
        const res = makeRes();
        const next = vi.fn();

        errorMiddleware(err, req as any, res as any, next);

        expect(res.status).toHaveBeenCalledWith(500);
        expect(res.json).toHaveBeenCalledWith({ error: 'Test error' });
        expect(logger.error).toHaveBeenCalled();
    });

    it('should return a JSON 404 response and not log for a 404', () => {
        const err = { message: 'Custom error', status: 404 };
        const req = {};
        const res = makeRes();
        const next = vi.fn();

        errorMiddleware(err as any, req as any, res as any, next);

        expect(res.status).toHaveBeenCalledWith(404);
        expect(res.json).toHaveBeenCalledWith({ error: 'Custom error' });
        expect(logger.error).not.toHaveBeenCalled();
    });

    it('should log other 5xx errors like 503', () => {
        const err = { message: 'Service Unavailable', status: 503 };
        const req = {};
        const res = makeRes();
        const next = vi.fn();

        errorMiddleware(err as any, req as any, res as any, next);

        expect(res.status).toHaveBeenCalledWith(503);
        expect(logger.error).toHaveBeenCalled();
    });

    it('should NOT log other 4xx errors like 403', () => {
        const err = { message: 'Forbidden', status: 403 };
        const req = {};
        const res = makeRes();
        const next = vi.fn();

        errorMiddleware(err as any, req as any, res as any, next);

        expect(res.status).toHaveBeenCalledWith(403);
        expect(logger.error).not.toHaveBeenCalled();
    });

    it('should hide error details behind a generic message in release mode', () => {
        vi.spyOn(version, 'isRelease').mockReturnValue(true);
        const err = new Error('Secret error');
        const req = {};
        const res = makeRes();
        const next = vi.fn();

        errorMiddleware(err, req as any, res as any, next);

        expect(res.status).toHaveBeenCalledWith(500);
        expect(res.json).toHaveBeenCalledWith({ error: 'Something went wrong' });
    });

    it('should use a generic 404 message in release mode', () => {
        vi.spyOn(version, 'isRelease').mockReturnValue(true);
        const err = { message: 'Custom error', status: 404 };
        const req = {};
        const res = makeRes();
        const next = vi.fn();

        errorMiddleware(err as any, req as any, res as any, next);

        expect(res.status).toHaveBeenCalledWith(404);
        expect(res.json).toHaveBeenCalledWith({ error: 'Page not found' });
    });

    it('should handle non-Error objects correctly', () => {
        const err = 'String error';
        const req = {};
        const res = makeRes();
        const next = vi.fn();

        errorMiddleware(err as any, req as any, res as any, next);

        expect(res.status).toHaveBeenCalledWith(500);
        expect(res.json).toHaveBeenCalledWith({ error: 'String error' });
    });
});
