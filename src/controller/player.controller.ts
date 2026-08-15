import { Request, Response, NextFunction } from 'express';
import { renderSuicideView, renderDeathView, renderCharacterView } from '@/view/player.view';
import { commitSuicide } from '@/service/player.service';
import { SuicideSchema } from '@/schema/player.schema';
import { statisticsRepository } from '@/repository/statistics.repository';
import { saveAndRedirect } from '@/middleware/session.middleware';

export const getSuicide = (req: Request, res: Response) => {
    res.send(renderSuicideView(res.locals.player, res.locals.flash));
};

export const postSuicide = (req: Request, res: Response, next: NextFunction) => {
    const parsed = SuicideSchema.safeParse(req.body);
    if (!parsed.success)
        return next(new Error('Invalid suicide selection'));

    if (parsed.data.suicide === 'yes') {
        void statisticsRepository.increment('total_players_suicided');
        commitSuicide(res.locals.player);

        return saveAndRedirect(req, res, next, '/death');
    }

    res.redirect('/');
};

export const getDeath = (req: Request, res: Response) => {
    res.send(renderDeathView(res.locals.player));
};

export const getRestart = (req: Request, res: Response) => {
    req.session.destroy(() => {
        res.redirect('/');
    });
};

export const getCharacter = (req: Request, res: Response) => {
    const player = res.locals.player;
    res.send(renderCharacterView(player, res.locals.flash));
};
