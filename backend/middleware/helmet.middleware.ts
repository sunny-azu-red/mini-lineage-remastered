import helmet from 'helmet';

// Vite's production build emits no inline scripts, so a plain 'self' script-src suffices.
// connect-src gains ws:/wss: so the Socket.IO WebSocket upgrade isn't blocked by CSP.
export const helmetMiddleware = helmet({
    contentSecurityPolicy: {
        directives: {
            ...helmet.contentSecurityPolicy.getDefaultDirectives(),
            'script-src': ["'self'"],
            'connect-src': ["'self'", 'ws:', 'wss:'],
        },
    },
});
