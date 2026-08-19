import { Request, Response, NextFunction } from 'express';
import { FlashMessage } from '@/interface';

export const flashMiddleware = (req: Request, res: Response, next: NextFunction) => {
    if (req.session && req.session.flash) {
        res.locals.flash = req.session.flash as FlashMessage;
        delete req.session.flash;
    } else
        res.locals.flash = null;

    next();
};
