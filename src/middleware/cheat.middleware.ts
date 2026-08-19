import { NextFunction, Request, Response } from 'express';
import { commitSuicide, isGameStarted } from '@/service/player.service';
import { statisticsRepository } from '@/repository/statistics.repository';

export const cheatMiddleware = (req: Request, res: Response, next: NextFunction) => {
    const player = res.locals.player;
    const isHighscores = req.path.startsWith('/highscores');

    // checking dead players — cowards and cheaters cannot post to the highscores
    if (player.dead) {
        const isSafePath = ['/death', '/restart'].includes(req.path);
        const canSubmitLegacy = req.method === 'POST' && req.path === '/highscores' && !player.coward && !player.cheated;
        if (!isSafePath && !canSubmitLegacy)
            return res.redirect('/death');

        return next(); // dead players don't need further checks
    }

    // checking alive players
    const isDeathPath = ['/death', '/restart'].includes(req.path);
    if (isDeathPath)
        return res.redirect('/');

    // kill ambushed players if they navigate away (cheaters)
    // only enforce on page navigations (HTML requests) — ignore background resource requests
    const isPageNavigation = req.headers.accept?.includes('text/html');
    if (player.ambushed && isPageNavigation && req.path !== '/battle') {
        void statisticsRepository.increment('total_players_cheated');
        commitSuicide(player);

        return res.redirect('/death');
    }

    // prevent already initialized players from accessing start, statistics and races routes
    if (isGameStarted(player) && ['/start', '/statistics', '/races'].includes(req.path))
        return res.redirect('/');

    // additional sanity checks for routes that require an initialized character
    if (!isGameStarted(player)) {
        const isUninitializedSafePath = ['/', '/start', '/statistics', '/races'].includes(req.path) || isHighscores;
        if (!isUninitializedSafePath)
            return res.redirect('/');
    }

    next();
};
