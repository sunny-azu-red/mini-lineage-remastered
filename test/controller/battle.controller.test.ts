import { describe, it, expect, vi, beforeEach } from 'vitest';
import { getBattle } from '@/controller/battle.controller';
import * as battleService from '@/service/battle.service';
import * as playerService from '@/service/player.service';
import * as mathService from '@/service/math.service';
import { statisticsRepository } from '@/repository/statistics.repository';
import * as sessionMiddleware from '@/middleware/session.middleware';
import * as battleView from '@/view/battle.view';

vi.mock('@/service/battle.service', () => ({
    simulateBattle: vi.fn(),
}));

vi.mock('@/service/player.service', () => ({
    resolveBattleOutcome: vi.fn(),
    getPlayerStats: vi.fn().mockReturnValue({
        attack: 16,
        defense: 10,
        crit: 4,
        maxHealth: 100,
        regen: 1,
        ambushRisk: 8,
        xpMultiplier: 1,
        adenaMultiplier: 1,
    }),
    applyEffect: vi.fn(),
}));

vi.mock('@/service/math.service', async (importOriginal) => {
    const actual = await importOriginal<typeof import('@/service/math.service')>();
    return {
        ...actual,
        randomInt: vi.fn(),
        calculateAmbushChance: vi.fn(),
    };
});

vi.mock('@/repository/statistics.repository', () => ({
    statisticsRepository: {
        increment: vi.fn().mockResolvedValue(undefined),
    },
}));

vi.mock('@/view/battle.view', () => ({
    renderBattlegroundView: vi.fn().mockReturnValue('rendered-view'),
}));

vi.mock('@/middleware/session.middleware', () => ({
    saveAndRedirect: vi.fn().mockImplementation((req, res, next, url) => res.redirect(url)),
}));

describe('battleController', () => {
    let req: any;
    let res: any;
    let next: any;
    let player: any;

    beforeEach(() => {
        vi.clearAllMocks();
        player = {
            raceId: 0,
            weaponId: 1,
            armorId: 1,
            health: 100,
            dead: false,
            ambushed: false,
            totalAmbushes: 0
        };
        req = {};
        res = {
            locals: { player },
            redirect: vi.fn(),
            send: vi.fn()
        };
        next = vi.fn();

        vi.mocked(battleService.simulateBattle).mockReturnValue({
            hpLost: 10,
            xpGained: 100,
            adenaGained: 50,
            enemiesKilled: 5,
            damageBlocked: 5,
            isCritical: false
        } as any);
        vi.mocked(playerService.resolveBattleOutcome).mockReturnValue(false);
        vi.mocked(mathService.calculateAmbushChance).mockReturnValue(false); // No ambush by default
    });

    it('should reset ambushed state if it was true at start', () => {
        player.ambushed = true;
        getBattle(req, res, next);
        expect(player.ambushed).toBe(false);
    });

    it('should simulate battle and apply results', () => {
        getBattle(req, res, next);
        expect(battleService.simulateBattle).toHaveBeenCalledWith(player);
        expect(playerService.resolveBattleOutcome).toHaveBeenCalledWith(player, expect.any(Object));
        expect(res.send).toHaveBeenCalledWith('rendered-view');
    });

    it('should attach sound "level" to flash message when level up occurs', () => {
        vi.mocked(playerService.resolveBattleOutcome).mockReturnValue(true);
        getBattle(req, res, next);
        expect(battleView.renderBattlegroundView).toHaveBeenCalledWith(
            player,
            expect.any(Object),
            expect.objectContaining({ sound: 'level', type: 'warning' })
        );
    });

    it('should redirect home if player is dead', () => {
        vi.mocked(playerService.resolveBattleOutcome).mockImplementation((p: any) => {
            p.dead = true;
            return false;
        });
        getBattle(req, res, next);
        expect(sessionMiddleware.saveAndRedirect).toHaveBeenCalledWith(req, res, next, '/death');
    });

    it('should increment totalAmbushes and statisticsRepository when ambush occurs', () => {
        vi.mocked(mathService.calculateAmbushChance).mockReturnValue(true); // Ambush trigger
        getBattle(req, res, next);

        expect(player.ambushed).toBe(true);
        expect(player.totalAmbushes).toBe(1);
        expect(statisticsRepository.increment).toHaveBeenCalledWith('total_ambushes');
    });

    it('should handle missing totalAmbushes property during ambush', () => {
        delete player.totalAmbushes;
        vi.mocked(mathService.calculateAmbushChance).mockReturnValue(true);
        getBattle(req, res, next);
        expect(player.totalAmbushes).toBe(1);
    });

    it('should not increment totalAmbushes when ambush does not occur', () => {
        vi.mocked(mathService.calculateAmbushChance).mockReturnValue(false); // No ambush
        getBattle(req, res, next);

        expect(player.ambushed).toBe(false);
        expect(player.totalAmbushes).toBe(0);
        expect(statisticsRepository.increment).not.toHaveBeenCalledWith('total_ambushes');
    });

    it('should track consecutive ambushes and apply Hexed debuff when consecutiveAmbushes >= 2', () => {
        vi.mocked(mathService.calculateAmbushChance).mockReturnValue(true);
        player.consecutiveAmbushes = 1;

        getBattle(req, res, next);

        expect(player.consecutiveAmbushes).toBe(2);
        expect(playerService.applyEffect).toHaveBeenCalled();
    });

    it('should reset consecutiveAmbushes when battle is not ambushed', () => {
        vi.mocked(mathService.calculateAmbushChance).mockReturnValue(false);
        player.consecutiveAmbushes = 3;

        getBattle(req, res, next);

        expect(player.consecutiveAmbushes).toBe(0);
        expect(playerService.applyEffect).not.toHaveBeenCalled();
    });
});
