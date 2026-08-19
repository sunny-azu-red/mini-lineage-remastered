import { MAX_LEVEL, HP_CONFIG } from '@/constant/game.constant';

export function randomInt(min: number, max: number): number {
    return Math.floor(Math.random() * (max - min + 1)) + min;
}

export function rollChance(chance: number): boolean {
    if (chance <= 0)
        return false;
    if (chance >= 100)
        return true;

    return Math.random() * 100 <= chance;
}

export function calculateCritChance(chance: number): boolean {
    return rollChance(chance);
}

export function calculateAmbushChance(chance: number): boolean {
    return rollChance(chance);
}

export function getAmbushEnemyCount(enemiesKilled: number, divisor: number = 4): number {
    return Math.max(1, Math.floor(enemiesKilled / divisor));
}

// -----------
// hp formulas
// -----------

export function getLowHealthThreshold(maxHp: number): number {
    return Math.floor(maxHp * HP_CONFIG.lowHealthThreshold);
}

export function isLowHealth(health: number, maxHp: number): boolean {
    return health > 0 && health <= getLowHealthThreshold(maxHp);
}

// ---------------------
// xp and level formulas
// ---------------------

export function calculateXpForLevel(level: number): number {
    return level <= 1 ? 0 : Math.round(130 * Math.pow(level, 2) + 130 * level);
}

export function calculateLevel(xp: number): number {
    let level = 1;
    while (!isMaxLevel(level) && calculateXpForLevel(level + 1) <= xp)
        level++;

    return level;
}

export function isMaxLevel(level: number): boolean {
    return level >= MAX_LEVEL;
}

export function calculatePercentage(value: number, total: number, precision: number = 0): number {
    if (total <= 0)
        return 0;

    let p = (value / total) * 100;
    p = Math.max(0, Math.min(100, p));
    if (precision === 0)
        return Math.round(p);

    const factor = Math.pow(10, precision);

    return Math.round(p * factor) / factor;
}

export function getXpProgress(xp: number) {
    const level = calculateLevel(xp);
    if (isMaxLevel(level))
        return {
            current: 0,
            required: 0,
            percent: 100
        };

    const prevLimit = calculateXpForLevel(level);
    const nextLimit = calculateXpForLevel(level + 1);
    const current = xp - prevLimit;
    const required = nextLimit - prevLimit;

    return {
        current,
        required,
        percent: calculatePercentage(current, required, 1)
    };
}

export function getXpNeededToLevelUp(xp: number): number {
    const level = calculateLevel(xp);
    if (isMaxLevel(level))
        return 0;

    return calculateXpForLevel(level + 1) - xp;
}

export function isLevelUp(oldXp: number, newXp: number): boolean {
    return calculateLevel(newXp) > calculateLevel(oldXp);
}

// -----------------------
// battle scaling formulas
// -----------------------

export function getEnemyCountRange(attackPower: number, minMult: number = 0.3, maxMult: number = 0.6): { min: number, max: number } {
    return {
        min: Math.max(1, Math.floor(attackPower * minMult)),
        max: Math.max(2, Math.floor(attackPower * maxMult))
    };
}

export function calculateDangerLevel(attackPower: number, multiplier: number = 0.6): number {
    return Math.floor(attackPower * multiplier);
}

export function calculateDamageBlocked(defensePower: number, exponent: number = 0.95, multiplier: number = 0.8): number {
    return Math.max(1, Math.floor(Math.pow(defensePower, exponent) * multiplier));
}

export function calculateBaseXpGained(attackPower: number, exponent: number = 1.5, multiplier: number = 0.8): number {
    return Math.floor(Math.pow(attackPower, exponent) * multiplier);
}

export function calculateBaseAdenaGained(attackPower: number, exponent: number = 2.65, multiplier: number = 0.05): number {
    return Math.floor(Math.pow(attackPower, exponent) * multiplier);
}
