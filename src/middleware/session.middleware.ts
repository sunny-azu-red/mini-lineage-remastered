import session from 'express-session';
import { Request, Response, NextFunction } from 'express';
import { env } from '@/config/env.config';
import { sessionStore } from '@/config/database.config';
import { PlayerState } from '@/interface';

const expressSession = session({
    secret: env.SESSION_SECRET,
    resave: false,
    saveUninitialized: false,
    store: sessionStore,
    cookie: {
        sameSite: 'lax',
        httpOnly: true,
        secure: env.IN_DOCKER,
    },
});

export const sessionMiddleware = (req: Request, res: Response, next: NextFunction) => {
    expressSession(req, res, (err) => {
        if (err)
            return next(err);

        if (res && res.locals) // safe check for res.locals (Socket.IO passes a mock response object {} which lacks locals)
            res.locals.player = req.session as PlayerState;

        next();
    });
};
