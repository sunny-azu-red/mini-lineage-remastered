import { describe, it, expect, vi, beforeEach } from 'vitest';
import { lockMiddleware } from '@/middleware/lock.middleware';
import { acquireSessionLock } from '@/util/lock.util';

vi.mock('@/util/lock.util', () => ({
    acquireSessionLock: vi.fn()
}));

describe('lockMiddleware', () => {
    let req: any;
    let res: any;
    let next: any;
    let release: any;

    beforeEach(() => {
        vi.clearAllMocks();
        release = vi.fn();
        vi.mocked(acquireSessionLock).mockResolvedValue(release);
        req = {
            session: {
                id: 'test-session-id',
                reload: vi.fn((cb) => cb(null))
            }
        };
        res = {
            on: vi.fn(),
            locals: {}
        };
        next = vi.fn();
    });

    it('should skip if no session ID', async () => {
        req.session = null;
        await lockMiddleware(req, res, next);
        expect(next).toHaveBeenCalled();
        expect(acquireSessionLock).not.toHaveBeenCalled();
    });

    it('should acquire lock and reload session', async () => {
        await lockMiddleware(req, res, next);

        expect(acquireSessionLock).toHaveBeenCalledWith('test-session-id');
        expect(res.on).toHaveBeenCalledWith('finish', expect.any(Function));
        expect(res.on).toHaveBeenCalledWith('close', expect.any(Function));
        expect(req.session.reload).toHaveBeenCalled();
        expect(next).toHaveBeenCalled();
    });

    it('should populate res.locals.player after reload', async () => {
        await lockMiddleware(req, res, next);
        expect(res.locals.player).toBe(req.session);
    });

    it('should gracefully handle session reload error and continue', async () => {
        const error = new Error('Reload failed');
        req.session.reload.mockImplementationOnce((cb: any) => cb(error));

        await lockMiddleware(req, res, next);

        expect(acquireSessionLock).toHaveBeenCalled();
        expect(req.session.reload).toHaveBeenCalled();
        expect(release).toHaveBeenCalled();
        expect(next).toHaveBeenCalledWith();
    });

    it('should handle acquireSessionLock error', async () => {
        const error = new Error('Lock failed');
        vi.mocked(acquireSessionLock).mockRejectedValueOnce(error);

        await lockMiddleware(req, res, next);

        expect(next).toHaveBeenCalledWith(error);
    });

    it('should only release the lock once even if both finish and close fire', async () => {
        const eventHandlers: Record<string, Function> = {};
        res.on = vi.fn((event: string, handler: Function) => {
            eventHandlers[event] = handler;
        });

        await lockMiddleware(req, res, next);

        // simulate both events firing (e.g. normal completion then socket close)
        eventHandlers['finish']();
        eventHandlers['close']();

        expect(release).toHaveBeenCalledTimes(1);
    });

    it('should release lock on close even if finish never fires (client abort)', async () => {
        const eventHandlers: Record<string, Function> = {};
        res.on = vi.fn((event: string, handler: Function) => {
            eventHandlers[event] = handler;
        });

        await lockMiddleware(req, res, next);

        // simulate only close firing (client disconnected)
        eventHandlers['close']();

        expect(release).toHaveBeenCalledTimes(1);
    });
});
