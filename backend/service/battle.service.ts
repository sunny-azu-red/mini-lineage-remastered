import { BattleResult, PlayerState } from '@/interface';
import { BATTLE_CONFIG } from '@/constant/game.constant';
import { randomInt, calculateCritChance, getEnemyCountRange, calculateDangerLevel, calculateDamageBlocked, calculateBaseXpGained, calculateBaseAdenaGained } from '@/service/math.service';
import { getPlayerStats } from '@/service/player.service';

export function simulateBattle(player: PlayerState): BattleResult {
    const stats = getPlayerStats(player);
    const attackPower = stats.attack;
    const defensePower = stats.defense;
    const isCritical = calculateCritChance(stats.crit);

    // enemies killed: scales dynamically with attack power
    const { min: minEnemies, max: maxEnemies } = getEnemyCountRange(attackPower, BATTLE_CONFIG.enemyCount.minMult, BATTLE_CONFIG.enemyCount.maxMult);
    let enemiesKilled = randomInt(minEnemies, maxEnemies);
    if (isCritical)
        enemiesKilled = Math.max(BATTLE_CONFIG.critReward.floor, Math.ceil(enemiesKilled * BATTLE_CONFIG.critReward.multiplier));

    // hp lost: danger scales linearly, armor scales sub-linearly to prevent invincibility
    const dangerLevel = calculateDangerLevel(attackPower, BATTLE_CONFIG.dangerLevel.scaling);
    const damageBlocked = calculateDamageBlocked(defensePower, BATTLE_CONFIG.damageBlocked.exponent, BATTLE_CONFIG.damageBlocked.scaling);
    const hpLost = Math.max(BATTLE_CONFIG.hpLost.floor, randomInt(BATTLE_CONFIG.hpLost.baseMin, BATTLE_CONFIG.hpLost.baseMax) + dangerLevel - damageBlocked);

    // experience gained & adena gained (with multipliers)
    let xpGained = (enemiesKilled * randomInt(BATTLE_CONFIG.xpGained.killMin, BATTLE_CONFIG.xpGained.killMax)) + calculateBaseXpGained(attackPower, BATTLE_CONFIG.xpGained.exponent, BATTLE_CONFIG.xpGained.scaling);
    let adenaGained = (enemiesKilled * randomInt(BATTLE_CONFIG.adenaGained.killMin, BATTLE_CONFIG.adenaGained.killMax)) + calculateBaseAdenaGained(attackPower, BATTLE_CONFIG.adenaGained.exponent, BATTLE_CONFIG.adenaGained.scaling);
    
    if (isCritical) { // critical hits multiply total rewards so they stay impactful at all attack power tiers
        xpGained = Math.ceil(xpGained * BATTLE_CONFIG.critReward.multiplier);
        adenaGained = Math.ceil(adenaGained * BATTLE_CONFIG.critReward.multiplier);
    }

    // Apply active XP / Adena multipliers (e.g. from buffs or Konami cheat)
    xpGained = Math.ceil(xpGained * stats.xpMultiplier);
    adenaGained = Math.ceil(adenaGained * stats.adenaMultiplier);

    return {
        enemiesKilled,
        hpLost,
        damageBlocked,
        xpGained,
        adenaGained,
        isCritical,
        isLevelUp: false
    };
}
