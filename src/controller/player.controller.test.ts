import { describe, it, expect, vi, beforeEach } from 'vitest';
import { postSuicide, getSuicide, getDeath, getRestart, getCharacter } from './player.controller';
import { commitSuicide } from '@/service/player.service';
import { statisticsRepository } from '@/repository/statistics.repository';
import * as playerView from '@/view/player.view';

vi.mock('@/service/player.service', () => ({
    commitSuicide: vi.fn(),
    isGameStarted: vi.fn(),
}));

vi.mock('@/service/math.service', () => ({
    calculateLevel: vi.fn().mockReturnValue(1),
}));

vi.mock('@/view/player.view', () => ({
    renderSuicideView: vi.fn().mockReturnValue('suicide-view'),
    renderDeathView: vi.fn().mockReturnValue('death-view'),
    renderCharacterView: vi.fn().mockReturnValue('character-view'),
}));

vi.mock('@/repository/statistics.repository', () => ({
    statisticsRepository: {
        increment: vi.fn().mockResolvedValue(undefined),
    },
}));

describe('playerController', () => {
    let req: any;
    let res: any;
    let next: any;

    beforeEach(() => {
        vi.clearAllMocks();
        req = {
            body: {},
            session: { 
                destroy: vi.fn((cb) => cb()),
                save: vi.fn((cb) => cb()) 
            }
        };
        res = {
            locals: { player: { experience: 100 } },
            redirect: vi.fn(),
            send: vi.fn()
        };
        next = vi.fn();
    });

    describe('getSuicide', () => {
        it('should send suicide view', () => {
            getSuicide(req, res);
            expect(playerView.renderSuicideView).toHaveBeenCalled();
            expect(res.send).toHaveBeenCalledWith('suicide-view');
        });
    });

    describe('postSuicide', () => {
        it('should increment total_players_suicided and commit suicide when confirmed', () => {
            req.body.suicide = 'yes';
            postSuicide(req, res, next);

            expect(statisticsRepository.increment).toHaveBeenCalledWith('total_players_suicided');
            expect(commitSuicide).toHaveBeenCalledWith(res.locals.player);
            expect(res.redirect).toHaveBeenCalledWith('/death');
        });

        it('should redirect home and not increment if suicide is not confirmed', () => {
            req.body.suicide = 'no';
            postSuicide(req, res, next);

            expect(statisticsRepository.increment).not.toHaveBeenCalled();
            expect(commitSuicide).not.toHaveBeenCalled();
            expect(res.redirect).toHaveBeenCalledWith('/');
        });

        it('should call next with error if validation fails', () => {
            req.body = {}; // missing suicide field
            postSuicide(req, res, next);

            expect(next).toHaveBeenCalled();
            expect(res.redirect).not.toHaveBeenCalled();
        });
    });

    describe('getDeath', () => {
        it('should send death view', () => {
            getDeath(req, res);
            expect(playerView.renderDeathView).toHaveBeenCalled();
            expect(res.send).toHaveBeenCalledWith('death-view');
        });
    });

    describe('getRestart', () => {
        it('should destroy session and redirect to home', () => {
            getRestart(req, res);
            expect(req.session.destroy).toHaveBeenCalled();
            expect(res.redirect).toHaveBeenCalledWith('/');
        });
    });

    describe('getCharacter', () => {
        it('should send character view', () => {
            getCharacter(req, res);
            expect(playerView.renderCharacterView).toHaveBeenCalled();
            expect(res.send).toHaveBeenCalledWith('character-view');
        });
    });
});
