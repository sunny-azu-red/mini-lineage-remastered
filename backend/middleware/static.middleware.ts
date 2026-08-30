import express, { Request, Response, NextFunction } from 'express';
import path from 'path';
import { isRelease } from '@/util/version.util';
import { GAME_VERSION } from '@/constant/game.constant';
import { env } from '@/config/env.config';

/**
 * Resolves Vite's build output (`dist/public`) for both static serving and app.ts's SPA
 * fallback. `__dirname` is fixed per-module, so app.ts calling this still resolves relative to
 * THIS file — which is why it's exported rather than re-derived there.
 *   dev  (ts-node,  <repo>/backend/middleware):      ../../dist/public
 *   prod (compiled, <repo>/dist/backend/middleware): ../../public
 */
export const getClientDistPath = (): string =>
    path.join(__dirname, isRelease(GAME_VERSION) ? '../../public' : '../../dist/public');

export const staticMiddleware = express.static(getClientDistPath());

/**
 * Dev-only stand-in for staticMiddleware + the SPA fallback. Vite serves the client in dev and
 * proxies `/api` and `/socket.io` here, so both must fall through. Anything else hitting :3000
 * directly gets a pointer rather than a possibly-stale `dist/public` build.
 */
export const devFallbackMiddleware = (req: Request, res: Response, next: NextFunction): void => {
    if (req.path.startsWith('/api/') || req.path.startsWith('/socket.io'))
        return next();

    const frontendUrl = `http://localhost:${env.DEV_FRONTEND_PORT}`;
    res.status(200).send(`This is the Mini-Lineage API/socket server. In development, open the app at <a href="${frontendUrl}">${frontendUrl}</a>.`);
};
