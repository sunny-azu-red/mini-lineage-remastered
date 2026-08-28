import helmet from 'helmet';

// The nonce-based script-src existed only to allow the legacy EJS templates' inline <head>
// script (see the deleted contextMiddleware/requestContext). Vite's production build emits no
// inline scripts — only `<script type="module" src="/assets/...">` — so a plain `'self'` is
// sufficient now. `connect-src` gains `ws:`/`wss:` so the browser's WebSocket upgrade to the
// Socket.IO server (now on the default `/socket.io` path, same origin) isn't blocked by CSP.
export const helmetMiddleware = helmet({
    contentSecurityPolicy: {
        directives: {
            ...helmet.contentSecurityPolicy.getDefaultDirectives(),
            'script-src': ["'self'"],
            'connect-src': ["'self'", 'ws:', 'wss:'],
        },
    },
});
