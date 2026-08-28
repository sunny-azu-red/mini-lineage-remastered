import express from 'express';
import path from 'path';
import compression from 'compression';
import { helmetMiddleware } from '@/middleware/helmet.middleware';
import { staticMiddleware, devFallbackMiddleware, getClientDistPath } from '@/middleware/static.middleware';
import { sessionMiddleware } from '@/middleware/session.middleware';
import { debugMiddleware } from '@/middleware/debug.middleware';
import { errorMiddleware } from '@/middleware/error.middleware';
import { env } from '@/config/env.config';

const app = express();

// Fix 3: `env.NODE_ENV` (not `isRelease()`, which conflates "distributable version
// string" with "which mode is this process running in") is the right signal for
// whether this process owns serving the built SPA. In development, the React client is
// served by Vite's own dev server on :5173 instead (see client/vite.config.ts) — static
// file serving and the SPA-fallback catch-all below are both gated off so port 3000 can
// never silently serve a stale `dist/public` build left over from an earlier `npm run
// build`, and hitting :3000 directly gets a clear explanation instead.
const isProduction = env.NODE_ENV === 'production';

app.set('trust proxy', 1);
app.use(helmetMiddleware);
app.use(compression());
if (isProduction)
    app.use(staticMiddleware);
app.use(sessionMiddleware);
app.use(debugMiddleware);

// Plan decision A10: express-session's saveUninitialized:false + Socket.IO's mock `res` object
// mean a socket-only session can never receive a Set-Cookie. This forces a real HTTP response to
// touch/save the session so the browser learns the sid before its first io() connect.
app.get('/api/bootstrap', (req, res) => {
    req.session.bootstrappedAt = Date.now();
    req.session.save(() => res.json({ ok: true }));
});

if (isProduction) {
    // SPA fallback — the legacy EJS app (and its `/app`-prefix workaround, see git history) is
    // gone, so the React client now genuinely owns `/` and every other non-API GET. Static
    // assets (`/assets/...`) are already served by `staticMiddleware` above; anything that
    // reaches this route is a client-side route the SPA's own router (useHistorySync) will
    // resolve, EXCEPT unmatched `/api/*` requests, which fall through to the JSON 404 handler
    // below instead of silently getting an HTML document back.
    app.get('*splat', (req, res, next) => {
        if (req.path.startsWith('/api/'))
            return next();

        res.sendFile(path.join(getClientDistPath(), 'index.html'), err => {
            if (err)
                next(err);
        });
    });
} else {
    // Dev-mode replacement (Fix 3) — see devFallbackMiddleware's own doc comment.
    app.get('*splat', devFallbackMiddleware);
}

// JSON 404 — anything that falls through the above (unmatched /api/* GETs, and any non-GET
// method against an unmatched path).
app.use((req, res) => {
    res.status(404).json({ error: `Not found: ${req.originalUrl}` });
});

app.use(errorMiddleware);

export default app;
