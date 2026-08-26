import { Request, Response, NextFunction } from 'express';
import { calculateLevel, calculateAmbushChance } from '@/service/math.service';
import { formatNumber } from '@/util/format.util';
import { makeFlash } from '@/util/game.util';
import { renderBattlegroundView } from '@/view/battle.view';
import { getPlayerStats, applyEffect, resolveBattleOutcome } from '@/service/player.service';
import { simulateBattle } from '@/service/battle.service';
import { EFFECTS_CONFIG } from '@/constant/game.constant';
import { statisticsRepository } from '@/repository/statistics.repository';
import { saveAndRedirect } from '@/middleware/session.middleware';

export const getBattle = (req: Request, res: Response, next: NextFunction) => {
    const player = res.locals.player;
    if (player.ambushed)
        player.ambushed = false;

    const results = simulateBattle(player);
    results.isLevelUp = resolveBattleOutcome(player, results);
    if (player.dead)
        return saveAndRedirect(req, res, next, '/death');

    const stats = getPlayerStats(player);
    let isAmbushed = calculateAmbushChance(stats.ambushRisk);
    if (isAmbushed) {
        player.ambushed = true;
        player.totalAmbushes = (player.totalAmbushes ?? 0) + 1;
        player.consecutiveAmbushes = (player.consecutiveAmbushes ?? 0) + 1;
        if (player.consecutiveAmbushes >= 2)
            applyEffect(player, EFFECTS_CONFIG.ambushDebuff);

        void statisticsRepository.increment('total_ambushes');
    } else {
        player.consecutiveAmbushes = 0;
    }

    const flash = results.isLevelUp
        ? makeFlash(`🎉 Congratulations! You have reached level ${formatNumber(calculateLevel(player.experience))}.`, 'warning', 'level')
        : res.locals.flash;

    res.send(renderBattlegroundView(player, results, flash));
};
