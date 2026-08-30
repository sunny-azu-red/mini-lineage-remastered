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

// NODE_ENV (not isRelease, which describes the version string rather than the run mode) decides
// whether this process serves the built SPA. In dev, Vite serves it — gating this off stops
// :3000 from silently serving a stale dist/public.
const isProduction = env.NODE_ENV === 'production';

app.set('trust proxy', 1);
app.use(helmetMiddleware);
app.use(compression());
if (isProduction)
    app.use(staticMiddleware);
app.use(sessionMiddleware);
app.use(debugMiddleware);

// saveUninitialized:false plus Socket.IO's mock `res` means a socket-only session can never
// receive a Set-Cookie. This forces a real HTTP response to save the session so the browser
// learns its sid before the first io() connect.
app.get('/api/bootstrap', (req, res) => {
    req.session.bootstrappedAt = Date.now();
    req.session.save(() => res.json({ ok: true }));
});

// SPA fallback: the client owns every non-API GET. Unmatched /api/* falls through to the JSON
// 404 below rather than silently getting an HTML document back.
app.get('*splat', isProduction
    ? (req, res, next) => {
        if (req.path.startsWith('/api/'))
            return next();

        res.sendFile(path.join(getClientDistPath(), 'index.html'), err => {
            if (err)
                next(err);
        });
    }
    : devFallbackMiddleware);

app.use((req, res) => {
    res.status(404).json({ error: `Not found: ${req.originalUrl}` });
});

app.use(errorMiddleware);

export default app;
