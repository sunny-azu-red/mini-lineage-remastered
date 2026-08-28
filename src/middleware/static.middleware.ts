import express from 'express';
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
