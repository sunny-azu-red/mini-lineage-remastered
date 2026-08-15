import { describe, it, expect, vi, beforeEach } from 'vitest';
import { cheatMiddleware } from './cheat.middleware';
import * as playerService from '@/service/player.service';
import { statisticsRepository } from '@/repository/statistics.repository';

vi.mock('@/service/player.service', () => ({
    commitSuicide: vi.fn(),
    isGameStarted: vi.fn()
}));

vi.mock('@/repository/statistics.repository', () => ({
    statisticsRepository: {
        increment: vi.fn().mockResolvedValue(undefined),
    },
}));

describe('cheatMiddleware', () => {
    let req: any;
    let res: any;
    let next: any;

    beforeEach(() => {
        vi.clearAllMocks();
        req = { path: '/', headers: { accept: 'text/html,application/xhtml+xml' } };
        res = {
            locals: { player: { dead: false, ambushed: false } },
            redirect: vi.fn()
        };
        next = vi.fn();
        vi.mocked(playerService.isGameStarted).mockReturnValue(true);
    });

    describe('dead players', () => {
        it('should redirect dead players to /death if on restricted path', () => {
            res.locals.player.dead = true;
            req.path = '/shop';

            cheatMiddleware(req, res, next);

            expect(res.redirect).toHaveBeenCalledWith('/death');
        });

        it('should allow dead players on safe paths', () => {
            res.locals.player.dead = true;
            req.path = '/death';

            cheatMiddleware(req, res, next);

            expect(next).toHaveBeenCalled();
        });

        it('should redirect dead players away from highscore GET paths', () => {
            res.locals.player.dead = true;
            req.path = '/highscores/elf';
            req.method = 'GET';

            cheatMiddleware(req, res, next);

            expect(res.redirect).toHaveBeenCalledWith('/death');
        });

        it('should allow dead players to POST highscores if not a coward', () => {
            res.locals.player.dead = true;
            res.locals.player.coward = false;
            req.path = '/highscores';
            req.method = 'POST';

            cheatMiddleware(req, res, next);

            expect(next).toHaveBeenCalled();
        });

        it('should redirect dead cowards away from highscore paths', () => {
            res.locals.player.dead = true;
            res.locals.player.coward = true;
            req.path = '/highscores/elf';

            cheatMiddleware(req, res, next);

            expect(res.redirect).toHaveBeenCalledWith('/death');
        });
    });

    describe('alive players on death paths', () => {
        it('should redirect alive players away from /death', () => {
            req.path = '/death';
            cheatMiddleware(req, res, next);
            expect(res.redirect).toHaveBeenCalledWith('/');
        });

        it('should redirect alive players away from /restart', () => {
            req.path = '/restart';
            cheatMiddleware(req, res, next);
            expect(res.redirect).toHaveBeenCalledWith('/');
        });
    });

    describe('ambushed players', () => {
        it('should kill ambushed player if they navigate to forbidden path', () => {
            res.locals.player.ambushed = true;
            req.path = '/some/random/path';

            cheatMiddleware(req, res, next);

            expect(statisticsRepository.increment).toHaveBeenCalledWith('total_players_cheated');
            expect(playerService.commitSuicide).toHaveBeenCalledWith(res.locals.player);
            expect(res.redirect).toHaveBeenCalledWith('/death');
        });

        it('should allow ambushed player on valid path', () => {
            res.locals.player.ambushed = true;
            req.path = '/battle';

            cheatMiddleware(req, res, next);

            expect(playerService.commitSuicide).not.toHaveBeenCalled();
            expect(next).toHaveBeenCalled();
        });

        it('should ignore non-HTML requests from ambushed players (e.g. DevTools source maps)', () => {
            res.locals.player.ambushed = true;
            req.path = '/socket.io/socket.io.js.map';
            req.headers = { accept: '*/*' };

            cheatMiddleware(req, res, next);

            expect(playerService.commitSuicide).not.toHaveBeenCalled();
            expect(next).toHaveBeenCalled();
        });
    });

    describe('non-initialized players', () => {
        it('should redirect non-initialized players to / if on restricted path', () => {
            vi.mocked(playerService.isGameStarted).mockReturnValue(false);
            req.path = '/battle';

            cheatMiddleware(req, res, next);

            expect(res.redirect).toHaveBeenCalledWith('/');
        });

        it('should allow non-initialized players on /start', () => {
            vi.mocked(playerService.isGameStarted).mockReturnValue(false);
            req.path = '/start';

            cheatMiddleware(req, res, next);

            expect(next).toHaveBeenCalled();
        });

        it('should allow non-initialized players on /statistics', () => {
            vi.mocked(playerService.isGameStarted).mockReturnValue(false);
            req.path = '/statistics';

            cheatMiddleware(req, res, next);

            expect(next).toHaveBeenCalled();
        });

        it('should allow non-initialized players on /races', () => {
            vi.mocked(playerService.isGameStarted).mockReturnValue(false);
            req.path = '/races';

            cheatMiddleware(req, res, next);

            expect(next).toHaveBeenCalled();
        });

        it('should allow non-initialized players on filtered highscore paths', () => {
            vi.mocked(playerService.isGameStarted).mockReturnValue(false);
            req.path = '/highscores/dark-elf';

            cheatMiddleware(req, res, next);

            expect(next).toHaveBeenCalled();
        });
    });

    describe('initialized players', () => {
        it('should allow initialized players on valid paths like /battle', () => {
            vi.mocked(playerService.isGameStarted).mockReturnValue(true);
            req.path = '/battle';

            cheatMiddleware(req, res, next);

            expect(next).toHaveBeenCalled();
        });

        it('should redirect initialized players away from /start', () => {
            vi.mocked(playerService.isGameStarted).mockReturnValue(true);
            req.path = '/start';

            cheatMiddleware(req, res, next);

            expect(res.redirect).toHaveBeenCalledWith('/');
        });

        it('should redirect initialized players away from /statistics', () => {
            vi.mocked(playerService.isGameStarted).mockReturnValue(true);
            req.path = '/statistics';

            cheatMiddleware(req, res, next);

            expect(res.redirect).toHaveBeenCalledWith('/');
        });

        it('should redirect initialized players away from /races', () => {
            vi.mocked(playerService.isGameStarted).mockReturnValue(true);
            req.path = '/races';

            cheatMiddleware(req, res, next);

            expect(res.redirect).toHaveBeenCalledWith('/');
        });
    });
});
