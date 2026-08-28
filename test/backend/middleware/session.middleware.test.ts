import { describe, it, expect, vi, beforeEach } from 'vitest';

// Use hoisted to ensure variables are available inside vi.mock
const { mockExpressSession } = vi.hoisted(() => ({
    mockExpressSession: vi.fn((req, res, next) => next())
}));

// Mock database.config to prevent real MySQL initialization
vi.mock('@/config/database.config', () => ({
    sessionStore: {
        get: vi.fn(),
        set: vi.fn()
    }
}));

// Mock express-session
vi.mock('express-session', () => ({
    default: vi.fn(() => mockExpressSession)
}));

import { sessionMiddleware } from '@/middleware/session.middleware';

describe('sessionMiddleware', () => {
    beforeEach(() => {
        vi.clearAllMocks();
    });

    it('should call expressSession and populate res.locals.player', () => {
        const req = { session: { name: 'Test Player' } } as any;
        const res = { locals: {} } as any;
        const next = vi.fn();

        sessionMiddleware(req, res, next);

        expect(mockExpressSession).toHaveBeenCalledWith(req, res, expect.any(Function));
        expect(res.locals.player).toBe(req.session);
        expect(next).toHaveBeenCalled();
    });

    it('should handle errors from expressSession', () => {
        const error = new Error('Session error');
        mockExpressSession.mockImplementationOnce((req: any, res: any, next: any) => next(error));

        const req = {} as any;
        const res = { locals: {} } as any;
        const next = vi.fn();

        sessionMiddleware(req, res, next);

        expect(next).toHaveBeenCalledWith(error);
    });


    it('should skip res.locals population if res is a mock object (Socket.IO case)', () => {
        const req = { session: { name: 'Test Player' } } as any;
        const res = {} as any; // No locals
        const next = vi.fn();

        sessionMiddleware(req, res, next);

        expect(mockExpressSession).toHaveBeenCalled();
        expect(res.locals).toBeUndefined();
        expect(next).toHaveBeenCalled();
    });
});
