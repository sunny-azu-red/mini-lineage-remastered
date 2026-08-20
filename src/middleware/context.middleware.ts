import crypto from 'crypto';
import { Request, Response, NextFunction } from 'express';
import { requestContext } from '@/context/request.context';

export const contextMiddleware = (req: Request, res: Response, next: NextFunction) => {
    const cspNonce = crypto.randomBytes(16).toString('base64');
    res.locals.cspNonce = cspNonce;
    requestContext.run({ cspNonce }, () => next());
};
