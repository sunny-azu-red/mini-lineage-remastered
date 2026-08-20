import helmet from 'helmet';
import { requestContext } from '@/context/request.context';

export const helmetMiddleware = helmet({
    contentSecurityPolicy: {
        directives: {
            ...helmet.contentSecurityPolicy.getDefaultDirectives(),
            'script-src': [
                "'self'",
                (req, res) =>
                    `'nonce-${requestContext.getStore()?.cspNonce || (res as any).locals?.cspNonce || ''}'`,
            ],
        },
    },
});
