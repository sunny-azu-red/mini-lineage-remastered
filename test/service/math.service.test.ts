import { describe, it, expect, vi } from 'vitest';
import { HP_CONFIG } from '@/constant/game.constant';
import {
    calculateXpForLevel,
    calculateLevel,
    isMaxLevel,
    isLevelUp,
    calculatePercentage,
    isLowHealth,
    getLowHealthThreshold,
    getXpNeededToLevelUp,
    getAmbushEnemyCount,
    getEnemyCountRange,
    calculateDamageBlocked,
    rollChance,
    calculateCritChance,
    calculateAmbushChance,
    getXpProgress,
} from '@/service/math.service';

describe('calculateXpForLevel', () => {
    it('returns 0 for level 1', () => expect(calculateXpForLevel(1)).toBe(0));
    it('returns correct value for level 2', () => expect(calculateXpForLevel(2)).toBe(130 * 4 + 130 * 2)); // 780
    it('returns a large number for level 80', () => expect(calculateXpForLevel(80)).toBeGreaterThan(800_000));
});

describe('calculateLevel', () => {
    it('returns level 1 at 0 xp', () => expect(calculateLevel(0)).toBe(1));
    it('returns level 1 just below level 2 threshold', () => expect(calculateLevel(calculateXpForLevel(2) - 1)).toBe(1));
    it('returns level 2 at exact threshold', () => expect(calculateLevel(calculateXpForLevel(2))).toBe(2));
    it('returns level 10 at that threshold', () => expect(calculateLevel(calculateXpForLevel(10))).toBe(10));
});

describe('isMaxLevel', () => {
    it('returns false at level 79', () => expect(isMaxLevel(79)).toBe(false));
    it('returns true at level 80', () => expect(isMaxLevel(80)).toBe(true));
    it('returns true above level 80', () => expect(isMaxLevel(81)).toBe(true));
});

describe('isLevelUp', () => {
    it('returns true when xp crosses a level boundary', () => {
        const threshold = calculateXpForLevel(2);
        expect(isLevelUp(threshold - 1, threshold)).toBe(true);
    });
    it('returns false when both xp values are in the same level', () => {
        expect(isLevelUp(0, calculateXpForLevel(2) - 1)).toBe(false);
    });
});

describe('calculatePercentage', () => {
    it('returns 50 for half', () => expect(calculatePercentage(50, 100)).toBe(50));
    it('clamps to 100 when value exceeds total', () => expect(calculatePercentage(150, 100)).toBe(100));
    it('clamps to 0 when value is negative', () => expect(calculatePercentage(-10, 100)).toBe(0));
    it('returns 0 when total is 0', () => expect(calculatePercentage(50, 0)).toBe(0));
    it('supports decimal precision', () => expect(calculatePercentage(1, 3, 1)).toBe(33.3));
});

describe('getLowHealthThreshold', () => {
    it('returns correctly based on HP_CONFIG', () => {
        expect(getLowHealthThreshold(100)).toBe(Math.floor(100 * HP_CONFIG.lowHealthThreshold));
        expect(getLowHealthThreshold(150)).toBe(Math.floor(150 * HP_CONFIG.lowHealthThreshold));
    });
});

describe('isLowHealth', () => {
    it('returns true at exactly the threshold', () => {
        const threshold = getLowHealthThreshold(100);
        expect(isLowHealth(threshold, 100)).toBe(true);
    });
    it('returns false one above threshold', () => {
        const threshold = getLowHealthThreshold(100);
        expect(isLowHealth(threshold + 1, 100)).toBe(false);
    });
    it('returns false at 0 hp (dead, not low)', () => expect(isLowHealth(0, 100)).toBe(false));
    it('returns false at full hp', () => expect(isLowHealth(100, 100)).toBe(false));
});

describe('getXpNeededToLevelUp', () => {
    it('returns 0 at max level', () => expect(getXpNeededToLevelUp(calculateXpForLevel(80))).toBe(0));
    it('returns a positive number mid-level', () => expect(getXpNeededToLevelUp(0)).toBeGreaterThan(0));
});

describe('getAmbushEnemyCount', () => {
    it('divides enemies by divisor', () => expect(getAmbushEnemyCount(8, 4)).toBe(2));
    it('returns minimum 1 when enemies < divisor', () => expect(getAmbushEnemyCount(2, 4)).toBe(1));
    it('returns minimum 1 at 0', () => expect(getAmbushEnemyCount(0)).toBe(1));
});

describe('getEnemyCountRange', () => {
    it('min is always at least 1', () => expect(getEnemyCountRange(1).min).toBeGreaterThanOrEqual(1));
    it('max is always at least min', () => {
        const { min, max } = getEnemyCountRange(7);
        expect(max).toBeGreaterThanOrEqual(min);
    });
});

describe('calculateDamageBlocked', () => {
    it('is always at least 1', () => expect(calculateDamageBlocked(1)).toBeGreaterThanOrEqual(1));
    it('higher armor stat blocks more', () => {
        expect(calculateDamageBlocked(88)).toBeGreaterThan(calculateDamageBlocked(2));
    });
});

describe('rollChance', () => {
    it('returns false when chance is 0', () => expect(rollChance(0)).toBe(false));
    it('returns false when chance is negative', () => expect(rollChance(-10)).toBe(false));
    it('returns true when chance is 100', () => expect(rollChance(100)).toBe(true));
    it('returns true when chance is above 100', () => expect(rollChance(150)).toBe(true));
    
    it('handles decimal precision (hit)', () => {
        vi.spyOn(Math, 'random').mockReturnValue(0.1666); // 16.66%
        expect(rollChance(16.67)).toBe(true);
        vi.restoreAllMocks();
    });
    
    it('handles decimal precision (miss)', () => {
        vi.spyOn(Math, 'random').mockReturnValue(0.1668); // 16.68%
        expect(rollChance(16.67)).toBe(false);
        vi.restoreAllMocks();
    });
});

describe('calculateCritChance', () => {
    it('behaves exactly like rollChance', () => {
        expect(calculateCritChance(0)).toBe(false);
        expect(calculateCritChance(100)).toBe(true);
    });
});

describe('calculateAmbushChance', () => {
    it('behaves exactly like rollChance', () => {
        expect(calculateAmbushChance(0)).toBe(false);
        expect(calculateAmbushChance(100)).toBe(true);
    });
});

describe('getXpProgress', () => {
    it('returns 100% and 0 current/required at max level', () => {
        const progress = getXpProgress(calculateXpForLevel(80));
        expect(progress.percent).toBe(100);
        expect(progress.current).toBe(0);
        expect(progress.required).toBe(0);
    });

    it('returns correct progress mid-level', () => {
        const level2 = calculateXpForLevel(2); // 780
        const level3 = calculateXpForLevel(3); // 130*9 + 130*3 = 1170 + 390 = 1560
        const xp = level2 + 390; // 780 + 390 = 1170 (exactly 50% towards level 3)
        const progress = getXpProgress(xp);
        expect(progress.percent).toBe(50);
        expect(progress.current).toBe(390);
        expect(progress.required).toBe(1560 - 780); // 780
    });
});
