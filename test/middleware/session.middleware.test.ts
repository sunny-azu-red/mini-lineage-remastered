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

import { sessionMiddleware, saveAndRedirect } from '@/middleware/session.middleware';

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

describe('saveAndRedirect', () => {
    beforeEach(() => {
        vi.clearAllMocks();
    });

    it('should save the session and redirect on success', () => {
        const req = { session: { save: vi.fn((cb) => cb()) } } as any;
        const res = { redirect: vi.fn() } as any;
        const next = vi.fn();
        const url = '/test-url';

        saveAndRedirect(req, res, next, url);

        expect(req.session.save).toHaveBeenCalled();
        expect(res.redirect).toHaveBeenCalledWith(url);
        expect(next).not.toHaveBeenCalled();
    });

    it('should call next with error if session.save fails', () => {
        const error = new Error('Save failed');
        const req = { session: { save: vi.fn((cb) => cb(error)) } } as any;
        const res = { redirect: vi.fn() } as any;
        const next = vi.fn();
        const url = '/test-url';

        saveAndRedirect(req, res, next, url);

        expect(req.session.save).toHaveBeenCalled();
        expect(res.redirect).not.toHaveBeenCalled();
        expect(next).toHaveBeenCalledWith(error);
    });
});
