import express from 'express';
import path from 'path';
import compression from 'compression';
import { helmetMiddleware } from '@/middleware/helmet.middleware';
import { staticMiddleware, getClientDistPath } from '@/middleware/static.middleware';
import { sessionMiddleware } from '@/middleware/session.middleware';
import { debugMiddleware } from '@/middleware/debug.middleware';
import { errorMiddleware } from '@/middleware/error.middleware';

const app = express();

app.set('trust proxy', 1);
app.use(helmetMiddleware);
app.use(compression());
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

// SPA fallback — the legacy EJS app (and its `/app`-prefix workaround, see git history) is gone,
// so the React client now genuinely owns `/` and every other non-API GET. Static assets
// (`/assets/...`) are already served by `staticMiddleware` above; anything that reaches this
// route is a client-side route the SPA's own router (useHistorySync) will resolve, EXCEPT
// unmatched `/api/*` requests, which fall through to the JSON 404 handler below instead of
// silently getting an HTML document back.
app.get('*splat', (req, res, next) => {
    if (req.path.startsWith('/api/'))
        return next();

    res.sendFile(path.join(getClientDistPath(), 'index.html'), err => {
        if (err)
            next(err);
    });
});

// JSON 404 — anything that falls through the above (unmatched /api/* GETs, and any non-GET
// method against an unmatched path).
app.use((req, res) => {
    res.status(404).json({ error: `Not found: ${req.originalUrl}` });
});

app.use(errorMiddleware);

export default app;
