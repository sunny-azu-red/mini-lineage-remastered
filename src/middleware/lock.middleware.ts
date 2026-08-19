import { Request, Response, NextFunction } from 'express';
import { acquireSessionLock } from '@/util/lock.util';
import { PlayerState } from '@/interface';

/**
 * lockMiddleware — acquires a per-session mutex so that concurrent
 * requests (double-clicks, rapid refreshes, WebSocket tick collisions) are
 * serialized. After acquiring the lock it reloads the session from the store
 * to guarantee the handler works on the latest data.
 */
export const lockMiddleware = (req: Request, res: Response, next: NextFunction) => {
    const sessionId = req.session?.id;
    if (!sessionId)
        return next();

    return acquireSessionLock(sessionId).then((release) => {
        // wrap release so it can only fire once per request
        let released = false;
        const safeRelease = () => {
            if (released)
                return;

            released = true;
            release();
        };

        // release on normal completion or client disconnect
        res.on('finish', safeRelease);
        res.on('close', safeRelease);

        // reload the session from the store to get the absolute latest data
        req.session.reload((err) => {
            if (err) {
                // session not yet persisted or expired — continue with in-memory session
                safeRelease();
                return next();
            }

            res.locals.player = req.session as PlayerState;
            next();
        });
    }).catch((err) => {
        next(err);
    });
};
