import type { PlayerState, BattleResult } from '@/interface';

/**
 * Shared fixtures for the server test suite. The defaults are the baseline every test file used
 * to redeclare; anything a given assertion depends on is passed as an override so its inputs stay
 * visible at the call site.
 */

export function makePlayer(overrides: Partial<PlayerState> = {}): PlayerState {
    return {
        name: 'Test Hero',
        raceId: 0, // Human — startHealth 100
        health: 100,
        adena: 0,
        experience: 0,
        weaponId: 0,
        armorId: 0,
        ...overrides,
    } as PlayerState;
}

export function makeBattleResult(overrides: Partial<BattleResult> = {}): BattleResult {
    return {
        enemiesKilled: 1,
        hpLost: 5,
        damageBlocked: 0,
        xpGained: 1,
        adenaGained: 1,
        isCritical: false,
        isLevelUp: false,
        ...overrides,
    };
}
