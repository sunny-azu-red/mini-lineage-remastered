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

// In dev, Vite serves the SPA — gating this off stops :3000 serving a stale dist/public.
const isProduction = env.NODE_ENV === 'production';

app.set('trust proxy', 1);
app.use(helmetMiddleware);
app.use(compression());
if (isProduction)
    app.use(staticMiddleware);
app.use(sessionMiddleware);
app.use(debugMiddleware);

// Forces a real HTTP response to save the session, so the browser has its sid before io() connects.
app.get('/api/bootstrap', (req, res) => {
    req.session.bootstrappedAt = Date.now();
    req.session.save(() => res.json({ ok: true }));
});

// SPA fallback: the client owns every non-API GET; unmatched /api/* falls through to the 404 below.
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
