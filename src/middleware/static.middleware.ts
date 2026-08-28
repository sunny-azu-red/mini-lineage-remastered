import express, { Request, Response, NextFunction } from 'express';
import path from 'path';
import { isRelease } from '@/util/version.util';
import { GAME_VERSION } from '@/constant/game.constant';

/**
 * Resolves the built client's directory (client/'s Vite output — see client/vite.config.ts's
 * `build.outDir: '../dist/public'`), for both static asset serving (below) and app.ts's
 * SPA-fallback `res.sendFile(index.html)`. Exported (rather than kept private) so app.ts can
 * reuse the exact same resolution instead of re-deriving it against its own `__dirname` (which
 * sits one directory shallower than this module and would need a different relative path to
 * land on the same directory — `__dirname` is fixed per-module regardless of call site, so
 * calling this function from app.ts still resolves relative to static.middleware.ts's location).
 *   dev   (ts-node, __dirname = <repo>/src/middleware):        ../../dist/public -> <repo>/dist/public
 *   prod  (compiled, __dirname = <repo>/dist/src/middleware):  ../../public      -> <repo>/dist/public
 * Both resolve to the same directory Vite builds into.
 */
export const getClientDistPath = (): string =>
    isRelease(GAME_VERSION)
        ? path.join(__dirname, '../../public')
        : path.join(__dirname, '../../dist/public');

export const staticMiddleware = express.static(getClientDistPath());

/**
 * Dev-mode stand-in for `staticMiddleware` + app.ts's SPA-fallback catch-all (Fix 3).
 * Only ever wired in when `env.NODE_ENV !== 'production'` — see app.ts. In development,
 * the React client is served by Vite's own dev server on :5173, which proxies `/api/*`
 * and the Socket.IO transport back to this server untouched (see client/vite.config.ts's
 * `server.proxy`, keyed on `/api` and `/socket.io`) — this middleware must let both of
 * those fall through via `next()` rather than swallowing them.
 *
 * Anything else reaching port 3000 directly in dev means someone bypassed Vite (a raw
 * `curl localhost:3000/`, an old bookmark, muscle memory from single-port days) — respond
 * with a clear pointer instead of what production would do here, which is silently
 * serving `dist/public` — a build directory with zero staleness guard that may not even
 * reflect the code currently running.
 */
export const devFallbackMiddleware = (req: Request, res: Response, next: NextFunction): void => {
    if (req.path.startsWith('/api/') || req.path.startsWith('/socket.io'))
        return next();

    res.status(200).send('This is the Mini-Lineage API/socket server. In development, open the app at http://localhost:5173.');
};
