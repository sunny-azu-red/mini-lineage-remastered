import { NextFunction, Request, Response } from 'express';
import { isRelease } from '@/util/version.util';
import { GAME_VERSION } from '@/constant/game.constant';
import { logger } from '@/config/logger.config';

/**
 * There is no more EJS error page to render — the SPA owns its own error UI
 * (ErrorBoundary/ErrorScreen) for anything a socket ack or `/api/bootstrap` can surface.
 * This handler now only catches errors thrown by Express itself (session-store failures,
 * a failed `res.sendFile` in the SPA-fallback route, etc.) and responds with plain JSON.
 */
export const errorMiddleware = (err: any, req: Request, res: Response, next: NextFunction) => {
    const status = err?.status || 500;
    const isSystemError = status >= 500;
    const isNotFound = status === 404;

    if (isSystemError)
        logger.error({ err }, '🔥 System Error');

    const message = !isRelease(GAME_VERSION)
        ? (err?.message ?? String(err))
        : (isNotFound ? 'Page not found' : 'Something went wrong');

    res.status(status).json({ error: message });
};
