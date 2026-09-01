import express, { Request, Response, NextFunction } from 'express';
import path from 'path';
import { isRelease } from '@/util/version.util';
import { GAME_VERSION } from '@/constant/game.constant';
import { env } from '@/config/env.config';

// Resolves Vite's build output, relative to THIS file (exported so app.ts gets the same path).
export const getClientDistPath = (): string =>
    path.join(__dirname, isRelease(GAME_VERSION) ? '../../public' : '../../dist/public');

export const staticMiddleware = express.static(getClientDistPath());

// Dev-only stand-in: Vite serves the client and proxies /api + /socket.io here, so both fall through.
export const devFallbackMiddleware = (req: Request, res: Response, next: NextFunction): void => {
    if (req.path.startsWith('/api/') || req.path.startsWith('/socket.io'))
        return next();

    const frontendUrl = `http://localhost:${env.DEV_FRONTEND_PORT}`;
    res.status(200).send(`This is the Mini-Lineage API/socket server. In development, open the app at <a href="${frontendUrl}">${frontendUrl}</a>.`);
};
