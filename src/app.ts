import express from 'express';
import path from 'path';
import compression from 'compression';
import gameRouter from '@/route/game.route';
import errorRouter from '@/route/error.route';
import { helmetMiddleware } from '@/middleware/helmet.middleware';
import { contextMiddleware } from '@/middleware/context.middleware';
import { staticMiddleware } from '@/middleware/static.middleware';
import { sessionMiddleware } from '@/middleware/session.middleware';
import { lockMiddleware } from '@/middleware/lock.middleware';
import { zoneMiddleware } from '@/middleware/zone.middleware';
import { cheatMiddleware } from '@/middleware/cheat.middleware';
import { flashMiddleware } from '@/middleware/flash.middleware';
import { debugMiddleware } from '@/middleware/debug.middleware';
import { errorMiddleware } from '@/middleware/error.middleware';
import { isRelease } from '@/util/version.util';
import { GAME_VERSION } from '@/constant/game.constant';

// New client (client/) build output — see client/vite.config.ts's `build.outDir: '../dist/public'`.
// Unlike static.middleware.ts's getStaticPath() (which lives one directory deeper, at
// src/middleware/, and so happens to resolve the SAME literal relative string to the right place
// in both dev and prod), app.ts sits directly in src/, one level shallower — so the dev/prod
// relative paths genuinely differ here and are computed explicitly instead of reusing that helper.
//   dev   (ts-node, __dirname = <repo>/src):          ../dist/public  -> <repo>/dist/public
//   prod  (compiled,  __dirname = <repo>/dist/src):   ../public       -> <repo>/dist/public
// Both resolve to the same directory Vite builds into.
const CLIENT_DIST_PATH = isRelease(GAME_VERSION)
    ? path.join(__dirname, '../public')
    : path.join(__dirname, '../dist/public');

const app = express();

app.set('trust proxy', 1);
app.use(contextMiddleware);
app.use(helmetMiddleware);
app.use(compression());
app.use(express.urlencoded({ extended: true }));
app.use(staticMiddleware);
app.use(sessionMiddleware);

// Additive (plan decision A10): express-session's saveUninitialized:false + Socket.IO's mock
// `res` object mean a socket-only session never receives a Set-Cookie. This forces a real HTTP
// response to touch/save the session so the browser learns the sid before its first io() connect.
// Placed immediately after sessionMiddleware (and before lock/zone/cheat) so it terminates the
// chain here and is unaffected by those middlewares' path-allowlist/ambush logic.
app.get('/api/bootstrap', (req, res) => {
    req.session.bootstrappedAt = Date.now();
    req.session.save(() => res.json({ ok: true }));
});

app.use(lockMiddleware);
app.use(zoneMiddleware);
app.use(debugMiddleware);
app.use(flashMiddleware);
app.use(cheatMiddleware);
app.use('/', gameRouter);

// --- New client (client/) SPA-fallback route --------------------------------------------------
// DECISION — a dedicated `/app` prefix, not bare `/`: the legacy `gameRouter` above already owns
// every "nice" path the new SPA would otherwise want (`/`, `/battle`, `/shop/weapons`,
// `/highscores/:raceLabel`, `/statistics`, `/races`, ...), and `errorRouter` right below installs
// a catch-all 404 `router.use()` that would swallow anything mounted after IT. There is no
// unclaimed path at the root left to "fall back" into without shadowing the still-live legacy app
// (which must remain untouched during this additive/parallel-run phase — see the plan). So,
// rather than fight the legacy router for `/`, the new client is served under its own prefix for
// the duration of this transition: `client/src/hooks/useHistorySync.ts` mirrors this by
// prefixing every `pushState` path the exact same way. Once the legacy app is demolished (a later
// task), this can simplify to a bare `/`/`/*splat` and own the root outright.
//
// Mounted after `gameRouter` (so it can never shadow any of its routes — there is no overlap) and
// before `errorRouter`'s catch-all (so it isn't shadowed in turn). Static assets themselves need
// no special handling here: Vite emits root-relative asset URLs (`/assets/...`), already served
// by the existing `staticMiddleware` above (which, in production, happens to resolve to this same
// `CLIENT_DIST_PATH` directory — see that constant's comment).
app.get(['/app', '/app/*splat'], (_req, res, next) => {
    res.sendFile(path.join(CLIENT_DIST_PATH, 'index.html'), err => {
        if (err)
            next(err);
    });
});

app.use('/', errorRouter);
app.use(errorMiddleware);

export default app;
