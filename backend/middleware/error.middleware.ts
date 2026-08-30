import { NextFunction, Request, Response } from 'express';
import { isRelease } from '@/util/version.util';
import { GAME_VERSION } from '@/constant/game.constant';
import { logger } from '@/config/logger.config';

/**
 * The SPA owns its own error UI, so this only catches errors thrown by Express itself
 * (session-store failures, a failed sendFile) and answers with plain JSON.
 */
export const errorMiddleware = (err: any, req: Request, res: Response, next: NextFunction) => {
    const status = err?.status || 500;

    if (status >= 500)
        logger.error({ err }, '🔥 System Error');

    const message = !isRelease(GAME_VERSION)
        ? (err?.message ?? String(err))
        : (status === 404 ? 'Page not found' : 'Something went wrong');

    res.status(status).json({ error: message });
};
