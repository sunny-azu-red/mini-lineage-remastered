import { describe, it, expect, vi, beforeEach } from 'vitest';
import { getHome, postGameStart } from '@/controller/game.controller';
import * as playerService from '@/service/player.service';
import * as gameView from '@/view/game.view';
import { RACES } from '@/constant/game.constant';

vi.mock('@/service/player.service', () => ({
    initializePlayer: vi.fn().mockReturnValue({ text: 'Welcome', type: 'success' }),
    isGameStarted: vi.fn(),
}));

vi.mock('@/view/game.view', () => ({
    renderGameStartView: vi.fn().mockReturnValue('start-view'),
    renderHomeView: vi.fn().mockReturnValue('home-view'),
}));

vi.mock('@/middleware/session.middleware', () => ({
    saveAndRedirect: vi.fn().mockImplementation((req, res, next, url) => res.redirect(url)),
}));

describe('gameController', () => {
    let req: any;
    let res: any;
    let next: any;

    beforeEach(() => {
        vi.clearAllMocks();
        req = { body: {} };
        res = {
            locals: { player: {} },
            send: vi.fn(),
            redirect: vi.fn(),
        };
        next = vi.fn();
    });

    describe('getHome', () => {
        it('should render game start view if game is not started', () => {
            vi.mocked(playerService.isGameStarted).mockReturnValue(false);
            getHome(req, res);
            expect(gameView.renderGameStartView).toHaveBeenCalled();
            expect(res.send).toHaveBeenCalledWith('start-view');
        });

        it('should render home view if game is started', () => {
            vi.mocked(playerService.isGameStarted).mockReturnValue(true);
            getHome(req, res);
            expect(gameView.renderHomeView).toHaveBeenCalled();
            expect(res.send).toHaveBeenCalledWith('home-view');
        });
    });

    describe('postGameStart', () => {
        it('should initialize player and redirect home on success', () => {
            req.body = { select_race: '0', name: 'Hero' };
            postGameStart(req, res, next);
            expect(playerService.initializePlayer).toHaveBeenCalledWith(res.locals.player, RACES[0], 'Hero');
            expect(res.redirect).toHaveBeenCalledWith('/');
        });

        it('should call next with error if validation fails', () => {
            req.body = {}; // missing fields
            postGameStart(req, res, next);
            expect(next).toHaveBeenCalledWith(expect.any(Error));
        });
    });
});
