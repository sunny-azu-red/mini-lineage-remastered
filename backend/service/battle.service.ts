import { BattleResult, PlayerState } from '@/interface';
import { BATTLE_CONFIG } from '@/constant/game.constant';
import { randomInt, calculateCritChance, getEnemyCountRange, calculateDangerLevel, calculateDamageBlocked, calculateBaseXpGained, calculateBaseAdenaGained } from '@/service/math.service';
import { getPlayerStats } from '@/service/player.service';

export function simulateBattle(player: PlayerState): BattleResult {
    const { enemyCount, dangerLevel, critReward, damageBlocked: blockCfg, xpGained: xpCfg, adenaGained: adenaCfg, hpLost: hpCfg } = BATTLE_CONFIG;
    const stats = getPlayerStats(player);
    const attack = stats.attack;
    const isCritical = calculateCritChance(stats.crit);

    // Enemies killed scales with attack power; a crit multiplies the whole group.
    const { min, max } = getEnemyCountRange(attack, enemyCount.minMult, enemyCount.maxMult);
    const rolled = randomInt(min, max);
    const enemiesKilled = isCritical
        ? Math.max(critReward.floor, Math.ceil(rolled * critReward.multiplier))
        : rolled;

    // Danger scales linearly with attack, armor mitigates sub-linearly.
    const blocked = calculateDamageBlocked(stats.defense, blockCfg.exponent, blockCfg.scaling);
    const hpLost = Math.max(hpCfg.floor, randomInt(hpCfg.baseMin, hpCfg.baseMax) + calculateDangerLevel(attack, dangerLevel.scaling) - blocked);

    // Crits multiply total rewards so they stay impactful at every attack tier.
    const critScale = isCritical ? critReward.multiplier : 1;
    const xpGained = Math.ceil(Math.ceil((enemiesKilled * randomInt(xpCfg.killMin, xpCfg.killMax) + calculateBaseXpGained(attack, xpCfg.exponent, xpCfg.scaling)) * critScale) * stats.xpMultiplier);
    const adenaGained = Math.ceil(Math.ceil((enemiesKilled * randomInt(adenaCfg.killMin, adenaCfg.killMax) + calculateBaseAdenaGained(attack, adenaCfg.exponent, adenaCfg.scaling)) * critScale) * stats.adenaMultiplier);

    return { enemiesKilled, hpLost, damageBlocked: blocked, xpGained, adenaGained, isCritical, isLevelUp: false };
}
