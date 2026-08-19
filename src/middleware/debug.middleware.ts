import { Request, Response, NextFunction } from 'express';
import { GAME_VERSION } from '@/constant/game.constant';
import { isRelease } from '@/util/version.util';
import { logger } from '@/config/logger.config';
import { formatSessionId } from '@/util/format.util';

export const debugMiddleware = (req: Request, res: Response, next: NextFunction) => {
    const start = Date.now();

    res.on('finish', () => {
        if (isRelease(GAME_VERSION))
            return;

        const duration = Date.now() - start;
        const sid = formatSessionId(req.sessionID);
        let message = `[${req.method}:${sid}] \x1b[35m${req.url} = ${res.statusCode} (${duration}ms)\x1b[0m`;

        if (req.method === 'POST' && req.body && Object.keys(req.body).length > 0)
            message += ` \x1b[33mPayload: ${JSON.stringify(req.body)}\x1b[0m`;

        if (req.session) {
            const state = { ...req.session };
            delete (state as any).cookie;

            if (Object.keys(state).length > 0)
                message += `\n\x1b[90m${JSON.stringify(state)}\x1b[0m`;
        }

        logger.debug(message);
    });

    next();
};
