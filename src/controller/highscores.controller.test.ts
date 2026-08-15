import { describe, it, expect, vi, beforeEach } from 'vitest';
import { getHighscores, postHighscores } from './highscores.controller';
import { highscoreRepository } from '@/repository/highscore.repository';
import * as highscoresView from '@/view/highscores.view';
import { RACES } from '@/constant/game.constant';

vi.mock('@/repository/highscore.repository', () => ({
    highscoreRepository: {
        insert: vi.fn().mockResolvedValue(undefined),
        findAll: vi.fn().mockResolvedValue([]),
    }
}));

vi.mock('@/view/highscores.view', () => ({
    renderHighscoresView: vi.fn().mockReturnValue('highscores-view'),
}));

vi.mock('@/service/math.service', () => ({
    calculateLevel: vi.fn().mockReturnValue(10),
}));

describe('highscoresController', () => {
    let req: any;
    let res: any;

    beforeEach(() => {
        vi.clearAllMocks();
        req = { params: {}, session: { destroy: vi.fn((cb) => cb()) } };
        res = {
            locals: { player: { dead: true, coward: false, raceId: 0, name: 'Hero', experience: 1000, adena: 100 } },
            send: vi.fn(),
            redirect: vi.fn(),
        };
    });

    describe('postHighscores', () => {
        it('should insert highscore and redirect to race-specific page for non-coward dead players', async () => {
            await postHighscores(req, res);
            expect(highscoreRepository.insert).toHaveBeenCalled();
            expect(req.session.destroy).toHaveBeenCalled();
            expect(res.redirect).toHaveBeenCalledWith('/highscores/human');
        });

        it('should redirect to /highscores if player is not dead', async () => {
            res.locals.player.dead = false;
            await postHighscores(req, res);
            expect(highscoreRepository.insert).not.toHaveBeenCalled();
            expect(res.redirect).toHaveBeenCalledWith('/highscores');
        });

        it('should fallback to /highscores if race is not found', async () => {
            res.locals.player.raceId = 999;
            await postHighscores(req, res);
            expect(res.redirect).toHaveBeenCalledWith('/highscores');
        });
    });

    describe('getHighscores', () => {
        it('should fetch all highscores if no race label provided', async () => {
            await getHighscores(req, res);
            expect(highscoreRepository.findAll).toHaveBeenCalledWith(undefined);
            expect(highscoresView.renderHighscoresView).toHaveBeenCalledWith([], undefined, res.locals.player);
            expect(res.send).toHaveBeenCalledWith('highscores-view');
        });

        it('should fetch filtered highscores if valid race label provided', async () => {
            req.params.raceLabel = 'human';
            await getHighscores(req, res);
            expect(highscoreRepository.findAll).toHaveBeenCalledWith(RACES[0].id);
        });

        it('should fetch all highscores if invalid race label provided', async () => {
            req.params.raceLabel = 'invalid-race';
            await getHighscores(req, res);
            expect(highscoreRepository.findAll).toHaveBeenCalledWith(undefined);
        });
    });
});
