import { describe, it, expect, vi } from 'vitest';
import { ItemType, PlayerState, RaceType } from '@/interface';
import { RACES, ARMORS, EFFECTS_CONFIG, CHARACTER_CONFIG, TICK_CONFIG } from '@/constant/game.constant';
import { DEATH_MESSAGES } from '@/constant/narratives.constant';
import {
    isGameStarted,
    initializePlayer,
    deductCost,
    killPlayer,
    commitSuicide,
    restoreHealth,
    purchaseItem,
    resolveBattleOutcome,
    processTick,
    processEffectExpiry,
    processRegenTick,
    getPlayerStats,
    applyEffect,
    getActiveEffects,
    syncZoneAuras,
    resetPlayer,
    resolveDeathReason,
} from '@/service/player.service';
import { statisticsRepository } from '@/repository/statistics.repository';
import { makePlayer } from '../factories';

vi.mock('@/repository/statistics.repository', () => ({
    statisticsRepository: {
        increment: vi.fn().mockResolvedValue(undefined),
        getAll: vi.fn(),
    },
}));

// The defaults this file's assertions were written against.
const localPlayer = (o: Partial<Parameters<typeof makePlayer>[0]> = {}) => makePlayer({ adena: 500, totalBattles: 0, totalAmbushes: 0, totalEnemiesKilled: 0, ...o });

describe('isGameStarted', () => {
    it('returns true for a fully initialized player', () => expect(isGameStarted(localPlayer())).toBe(true));
    it('returns false when raceId is missing', () => expect(isGameStarted({} as PlayerState)).toBe(false));
    it('returns false when raceId is undefined explicitly', () => {
        const p = localPlayer();
        delete (p as any).raceId;
        expect(isGameStarted(p)).toBe(false);
    });
});

describe('initializePlayer', () => {
    it('populates player state and returns an info flash message', () => {
        const p = {} as any;
        const race = RACES[0]; // Human
        const flash = initializePlayer(p, race, 'Arthur');

        expect(p.name).toBe('Arthur');
        const stats = getPlayerStats(p);
        expect(stats.maxHealth).toBe(race.startHealth + 20);
        expect(p.health).toBe(stats.maxHealth);
        expect(p.adena).toBe(race.startAdena);
        expect(p.experience).toBe(0);
        expect(p.totalAmbushes).toBe(0);
        expect(p.effects).toHaveLength(1);
        expect(p.effects[0].id).toBe('newbie_blessing');
        expect(stats.defense).toBe(ARMORS[0].stat + 2);
        expect(stats.ambushRisk).toBe(race.ambushChance - 4);
        expect(flash.type).toBe('info');
        expect(flash.sound).toBe('start');
        expect(flash.text).toContain('Human');
        // Verify repository increment for new players
        expect(statisticsRepository.increment).toHaveBeenCalledWith('total_players');
        expect(statisticsRepository.increment).toHaveBeenCalledWith('total_adena', race.startAdena);
    });

    it('stores the provided name', () => {
        const p = {} as any;
        initializePlayer(p, RACES[0], 'Merlin');
        expect(p.name).toBe('Merlin');
    });
});

describe('deductCost', () => {
    it('deducts adena and returns true when affordable', () => {
        const p = localPlayer({ adena: 100 });
        expect(deductCost(p, 50)).toBe(true);
        expect(p.adena).toBe(50);
    });
    it('deducts nothing and returns false when not affordable', () => {
        const p = localPlayer({ adena: 10 });
        expect(deductCost(p, 50)).toBe(false);
        expect(p.adena).toBe(10);
    });
    it('succeeds when player has exact amount, leaving 0 adena', () => {
        const p = localPlayer({ adena: 50 });
        expect(deductCost(p, 50)).toBe(true);
        expect(p.adena).toBe(0);
    });
});

describe('killPlayer', () => {
    it('sets health to 0, dead to true, clears active effects, and increments total_deaths', () => {
        const p = localPlayer({
            health: 75,
            effects: [
                { ...EFFECTS_CONFIG.smokedSausage }
            ]
        });
        killPlayer(p);
        expect(p.health).toBe(0);
        expect(p.dead).toBe(true);
        expect(p.effects).toEqual([]);
        expect(getActiveEffects(p)).toEqual([]);
        expect(statisticsRepository.increment).toHaveBeenCalledWith('total_deaths');
    });
});

describe('commitSuicide', () => {
    it('kills the player and marks them as a coward', () => {
        const p = localPlayer({ health: 100 });
        commitSuicide(p);
        expect(p.health).toBe(0);
        expect(p.dead).toBe(true);
        expect(p.coward).toBe(true);
    });
});

describe('restoreHealth', () => {
    it('restores partial HP and returns amount healed', () => {
        const p = localPlayer({ raceId: 0, health: 50 });
        const healed = restoreHealth(p, 20);
        expect(p.health).toBe(70);
        expect(healed).toBe(20);
    });
    it('clamps to maxHp — no over-healing — and returns clamped amount', () => {
        const p = localPlayer({ raceId: 0, health: 90 });
        const healed = restoreHealth(p, 999);
        expect(p.health).toBe(RACES[0].startHealth); // 100
        expect(healed).toBe(10);
    });
    it('returns 0 when already at full health', () => {
        const p = localPlayer({ raceId: 0, health: RACES[0].startHealth });
        const healed = restoreHealth(p, 20);
        expect(healed).toBe(0);
    });
});

describe('applyEffect', () => {
    it('applies a new effect and preserves distinct groups', () => {
        const p = localPlayer({ raceId: 0, effects: [] });
        applyEffect(p, { id: 'food_1', type: 'buff', group: 'food', emoji: '🥓', label: 'Food 1', modifiers: [] });
        applyEffect(p, { id: 'potion_1', type: 'buff', group: 'potion', emoji: '🧪', label: 'Potion 1', modifiers: [] });
        expect(p.effects?.length).toBe(2);
        expect(p.effects?.map(e => e.id)).toEqual(['food_1', 'potion_1']);
    });

    it('replaces active effects with the same group', () => {
        const p = localPlayer({ raceId: 0, effects: [] });
        applyEffect(p, { id: 'food_1', type: 'buff', group: 'food', emoji: '🥓', label: 'Food 1', modifiers: [] });
        applyEffect(p, { id: 'food_2', type: 'buff', group: 'food', emoji: '🍖', label: 'Food 2', modifiers: [] });
        expect(p.effects?.length).toBe(1);
        expect(p.effects?.[0].id).toBe('food_2');
    });

    it('drops effects that already expired while applying a new one', () => {
        const p = localPlayer({
            raceId: 0,
            effects: [
                { id: 'stale', type: 'buff', emoji: '🍎', label: 'Stale', modifiers: [], expiresAt: Date.now() - 1000 },
                { id: 'live', type: 'buff', emoji: '🛡️', label: 'Live', modifiers: [], expiresAt: Date.now() + 60_000 },
            ],
        });
        applyEffect(p, { id: 'fresh', type: 'buff', emoji: '⚡', label: 'Fresh', modifiers: [] });
        expect(p.effects?.map(e => e.id)).toEqual(['live', 'fresh']);
    });

    it('replaces effect by id when group is not specified', () => {
        const p = localPlayer({ raceId: 0, effects: [] });
        applyEffect(p, { id: 'custom_buff', type: 'buff', emoji: '⚡', label: 'Speed', durationMs: 10000, modifiers: [] });
        applyEffect(p, { id: 'custom_buff', type: 'buff', emoji: '⚡', label: 'Speed Refreshed', durationMs: 20000, modifiers: [] });
        expect(p.effects?.length).toBe(1);
        expect(p.effects?.[0].label).toBe('Speed Refreshed');
    });
});

describe('purchaseItem — weapon', () => {
    it('deducts cost and updates weaponId on success', () => {
        const p = localPlayer({ adena: 1000, weaponId: 0 });
        const result = purchaseItem(p, ItemType.Weapon, 1); // Elven Needle costs 300
        expect(result?.success).toBe(true);
        expect(p.weaponId).toBe(1);
        expect(p.adena).toBe(700);
        expect(statisticsRepository.increment).toHaveBeenCalledWith('total_weapons_bought');
        expect(statisticsRepository.increment).toHaveBeenCalledWith('total_adena_spent', 300);
    });
    it('fails when adena is insufficient', () => {
        const p = localPlayer({ adena: 10, weaponId: 0 });
        const result = purchaseItem(p, ItemType.Weapon, 1);
        expect(result?.success).toBe(false);
        expect(p.adena).toBe(10);
        expect(p.weaponId).toBe(0);
    });
    it('fails when already owning the item', () => {
        const p = localPlayer({ adena: 1000, weaponId: 1 });
        const result = purchaseItem(p, ItemType.Weapon, 1);
        expect(result?.success).toBe(false);
        expect(p.adena).toBe(1000); // no deduction
    });
});

describe('purchaseItem — armor', () => {
    it('deducts cost and updates armorId and increments stats', () => {
        const p = localPlayer({ adena: 1000, armorId: 0 });
        const result = purchaseItem(p, ItemType.Armor, 1); // Brigandine Leathers costs 500
        expect(result?.success).toBe(true);
        expect(p.armorId).toBe(1);
        expect(p.adena).toBe(500);
        expect(statisticsRepository.increment).toHaveBeenCalledWith('total_armors_bought');
        expect(statisticsRepository.increment).toHaveBeenCalledWith('total_adena_spent', 500);
    });

    it('fails when already owning the armor', () => {
        const p = localPlayer({ adena: 1000, armorId: 1 });
        const result = purchaseItem(p, ItemType.Armor, 1);
        expect(result?.success).toBe(false);
        expect(p.adena).toBe(1000);
    });

    it('returns null when item ID is invalid', () => {
        const p = localPlayer();
        const result = purchaseItem(p, ItemType.Weapon, 999);
        expect(result).toBeNull();
    });
});
describe('purchaseItem — food', () => {
    it('heals the player on purchase and increments stats', () => {
        const p = localPlayer({ adena: 100, health: 50, raceId: 0 });
        const result = purchaseItem(p, ItemType.Food, 0); // Spiced Ale: stat 4, cost 7
        expect(result?.success).toBe(true);
        expect(p.health).toBe(54);
        expect(p.adena).toBe(93);
        expect(statisticsRepository.increment).toHaveBeenCalledWith('total_food_bought');
        expect(statisticsRepository.increment).toHaveBeenCalledWith('total_adena_spent', 7);
        expect(statisticsRepository.increment).toHaveBeenCalledWith('total_hp_healed', 4);
    });

    it('applies buff effect when purchasing high-tier food', () => {
        const p = localPlayer({ adena: 100, health: 50, raceId: 0 });
        const result = purchaseItem(p, ItemType.Food, 2); // Smoked Sausage: stat 15, cost 60, effect: Satisfied (+10 maxHp)
        expect(result?.success).toBe(true);
        expect(p.effects?.length).toBe(1);
        expect(p.effects?.[0].id).toBe('satisfied');
        expect(result?.text).toBe(
            `You have bought 🌭 Smoked Sausage.\nYou feel invigorated by the 🥓 Satisfied buff!\nYou feel your strength returning, bringing you to 65 HP.`
        );
    });

    it('heals into newly expanded max HP when purchasing food at full base HP', () => {
        const p = localPlayer({ adena: 100, health: 100, raceId: 0 }); // Human base max HP = 100
        const result = purchaseItem(p, ItemType.Food, 2); // Smoked Sausage: stat 15, cost 60, effect: Satisfied (+10 maxHp)
        expect(result?.success).toBe(true);
        expect(p.effects?.length).toBe(1);
        expect(p.health).toBe(110); // Healed from 100 into the new 110 ceiling
        expect(result?.text).toBe(
            `You have bought 🌭 Smoked Sausage.\nYou feel invigorated by the 🥓 Satisfied buff!\nYou feel your strength returning, bringing you to 110 HP.`
        );
    });

    it('replaces previous food buff when purchasing another food buff without stacking', () => {
        const p = localPlayer({
            adena: 5000,
            health: 50,
            raceId: 0,
            effects: [
                { id: 'satisfied', type: 'buff', group: 'food', emoji: '🥓', label: 'Satisfied', modifiers: [{ type: 'maxHealth', value: 10 }] }
            ]
        });

        // Buy Hearty Mash (Well Fed: +30 maxHp)
        const result1 = purchaseItem(p, ItemType.Food, 3);
        expect(result1?.success).toBe(true);
        expect(p.effects?.length).toBe(1);
        expect(p.effects?.[0].id).toBe('well_fed');

        // Buy Roasted Pheasant (Gourmet Feast: +60 maxHp)
        const result2 = purchaseItem(p, ItemType.Food, 4);
        expect(result2?.success).toBe(true);
        expect(p.effects?.length).toBe(1);
        expect(p.effects?.[0].id).toBe('gourmet_feast');
    });

    it('preserves non-food effects when replacing food buff', () => {
        const p = localPlayer({
            adena: 1000,
            health: 50,
            raceId: 0,
            effects: [
                { ...EFFECTS_CONFIG.restingAura },
                { ...EFFECTS_CONFIG.konamiCheat },
                { ...EFFECTS_CONFIG.smokedSausage }
            ]
        });

        purchaseItem(p, ItemType.Food, 3); // Hearty Mash
        const effectIds = p.effects?.map(e => e.id);
        expect(effectIds).toEqual(['resting', 'konami_cheat', 'well_fed']);
    });
});

describe('purchaseItem — hostile input', () => {
    // EQUIPMENT is keyed by ItemType. If it were a plain object, `EQUIPMENT['constructor']` would
    // resolve up the prototype chain to a truthy value and be treated as a real equipment slot —
    // deducting adena and writing junk onto the session before throwing. A null-prototype map
    // cannot. Unreachable through the Zod-validated handler, but the service must not rely on that.
    it.each(['constructor', 'toString', 'valueOf', 'hasOwnProperty', '__proto__'])(
        'treats the inherited key %s as an unknown item type, not an equipment slot',
        (key) => {
            const p = localPlayer({ adena: 1000, weaponId: 0, armorId: 0 });
            vi.mocked(statisticsRepository.increment).mockClear();

            expect(() => purchaseItem(p, key as unknown as ItemType, 0)).not.toThrow();

            // Whatever it resolved to, it must not have written an equipment slot or junk key.
            expect(p.weaponId).toBe(0);
            expect(p.armorId).toBe(0);
            expect(Object.keys(p)).not.toContain('undefined');
            expect(statisticsRepository.increment).not.toHaveBeenCalledWith(undefined);
        },
    );
});

describe('processRegenTick — non-finite state', () => {
    // The guard is written positively (`regen > 0 && health < maxHealth`) precisely because the
    // inverted form falls through on NaN and would persist NaN health plus a NaN statistic,
    // which the 5s tick would then broadcast forever.
    it('bails out instead of persisting NaN health', () => {
        const p = localPlayer({ raceId: 0, health: NaN });
        p.effects = [{ ...EFFECTS_CONFIG.restingAura }];
        vi.mocked(statisticsRepository.increment).mockClear();

        expect(processRegenTick(p)).toBe(false);
        expect(statisticsRepository.increment).not.toHaveBeenCalled();
    });
});

describe('purchaseItem — statistics fired', () => {
    // Pins the COMPLETE set of counters each purchase touches. A `toHaveBeenCalledWith` check
    // alone cannot catch an increment that was dropped, duplicated, or given the wrong amount.
    const incrementsFor = (run: () => void): Array<[string, number | undefined]> => {
        vi.mocked(statisticsRepository.increment).mockClear();
        run();
        return vi.mocked(statisticsRepository.increment).mock.calls
            .map(([field, amount]) => [field, amount] as [string, number | undefined])
            .sort((a, b) => a[0].localeCompare(b[0]));
    };

    it('a weapon purchase spends adena and counts the weapon, nothing else', () => {
        const p = localPlayer({ adena: 1000, weaponId: 0 });
        expect(incrementsFor(() => purchaseItem(p, ItemType.Weapon, 1))).toEqual([
            ['total_adena_spent', 300],
            ['total_weapons_bought', undefined],
        ]);
    });

    it('an armor purchase spends adena and counts the armor, nothing else', () => {
        const p = localPlayer({ adena: 1000, armorId: 0 });
        expect(incrementsFor(() => purchaseItem(p, ItemType.Armor, 1))).toEqual([
            ['total_adena_spent', 500],
            ['total_armors_bought', undefined],
        ]);
    });

    it('a food purchase spends adena, counts the meal, and records the HP actually healed', () => {
        const p = localPlayer({ adena: 1000, health: 50, raceId: 0 }); // Spiced Ale: 4 HP, 7 adena
        expect(incrementsFor(() => purchaseItem(p, ItemType.Food, 0))).toEqual([
            ['total_adena_spent', 7],
            ['total_food_bought', undefined],
            ['total_hp_healed', 4],
        ]);
    });

    it('food records only the HP actually restored when it would overheal', () => {
        const p = localPlayer({ adena: 1000, health: 98, raceId: 0 }); // 100 max, heals 4 -> only 2 land
        expect(incrementsFor(() => purchaseItem(p, ItemType.Food, 0))).toContainEqual(['total_hp_healed', 2]);
    });

    it('a rejected purchase spends nothing and counts nothing', () => {
        const broke = localPlayer({ adena: 1, weaponId: 0 });
        expect(incrementsFor(() => purchaseItem(broke, ItemType.Weapon, 1))).toEqual([]);

        const owned = localPlayer({ adena: 100_000, weaponId: 1 });
        expect(incrementsFor(() => purchaseItem(owned, ItemType.Weapon, 1))).toEqual([]);

        const unknown = localPlayer({ adena: 100_000 });
        expect(incrementsFor(() => purchaseItem(unknown, ItemType.Weapon, 999))).toEqual([]);
    });
});

describe('resolveBattleOutcome', () => {
    it('kills the player on lethal damage', () => {
        const p = localPlayer({ health: 5 });
        const flash = resolveBattleOutcome(p, { hpLost: 10, xpGained: 100, adenaGained: 50, enemiesKilled: 3, damageBlocked: 2, isCritical: false } as any);
        expect(p.dead).toBe(true);
        expect(p.health).toBe(0);
        expect(flash).toBe(false);
    });
    it('returns a level-up flash and restores hp on level-up', () => {
        const p = localPlayer({ health: 90, experience: 0, raceId: 0 });
        // Level 2 threshold is calculateXpForLevel(2) = 780
        const flash = resolveBattleOutcome(p, { hpLost: 0, xpGained: 780, adenaGained: 0, enemiesKilled: 0, damageBlocked: 0, isCritical: false } as any);
        expect(flash).toBe(true);
        expect(p.health).toBe(RACES[0].startHealth); // full HP on level up
    });
    it('increments total_levels_gained and total_hp_healed on level-up', () => {
        const p = localPlayer({ health: 60, experience: 0, raceId: 0 });
        resolveBattleOutcome(p, { hpLost: 0, xpGained: 780, adenaGained: 0, enemiesKilled: 0, damageBlocked: 0, isCritical: false } as any);
        expect(statisticsRepository.increment).toHaveBeenCalledWith('total_levels_gained');
        expect(statisticsRepository.increment).toHaveBeenCalledWith('total_hp_healed', 40); // 100 - 60
    });
    it('returns null flash and updates stats on normal battle', () => {
        const p = localPlayer({ health: 80, adena: 100, experience: 0 });
        const flash = resolveBattleOutcome(p, { hpLost: 10, xpGained: 50, adenaGained: 25, enemiesKilled: 5, damageBlocked: 3, isCritical: false } as any);
        expect(flash).toBe(false);
        expect(p.health).toBe(70);
        expect(p.adena).toBe(125);
        expect(p.experience).toBe(50);
        expect(p.totalBattles).toBe(1);
        expect(p.totalEnemiesKilled).toBe(5);
    });

    it('increments global stats during battle', () => {
        const p = localPlayer({ health: 100 });
        resolveBattleOutcome(p, { hpLost: 10, xpGained: 50, adenaGained: 25, enemiesKilled: 5, damageBlocked: 7, isCritical: false } as any);

        expect(statisticsRepository.increment).toHaveBeenCalledWith('total_battles');
        expect(statisticsRepository.increment).toHaveBeenCalledWith('total_enemies_killed', 5);
        expect(statisticsRepository.increment).toHaveBeenCalledWith('total_adena_generated', 25);
        expect(statisticsRepository.increment).toHaveBeenCalledWith('total_adena', 25);
        expect(statisticsRepository.increment).toHaveBeenCalledWith('total_hp_lost', 10);
        expect(statisticsRepository.increment).toHaveBeenCalledWith('total_xp_gained', 50);
        expect(statisticsRepository.increment).toHaveBeenCalledWith('total_damage_blocked', 7);
    });

    it('increments total_deaths when player dies', () => {
        const p = localPlayer({ health: 5 });
        resolveBattleOutcome(p, { hpLost: 10, xpGained: 0, adenaGained: 0, enemiesKilled: 0, damageBlocked: 0, isCritical: false } as any);
        expect(statisticsRepository.increment).toHaveBeenCalledWith('total_deaths');
    });

    it('increments total_critical_hits when isCritical is true', () => {
        const p = localPlayer({ health: 100 });
        resolveBattleOutcome(p, { hpLost: 10, xpGained: 50, adenaGained: 25, enemiesKilled: 5, damageBlocked: 7, isCritical: true } as any);
        expect(statisticsRepository.increment).toHaveBeenCalledWith('total_critical_hits');
    });

    it('handles missing totalBattles and totalEnemiesKilled during resolution', () => {
        const p = localPlayer({ health: 100 });
        delete (p as any).totalBattles;
        delete (p as any).totalEnemiesKilled;
        resolveBattleOutcome(p, { hpLost: 0, xpGained: 0, adenaGained: 0, enemiesKilled: 10, damageBlocked: 0, isCritical: false } as any);
        expect(p.totalBattles).toBe(1);
        expect(p.totalEnemiesKilled).toBe(10);
    });
});

describe('initializePlayer — age definitions', () => {
    it('marks as youth when age <= 23', () => {
        const p = {} as any;
        vi.spyOn(Math, 'random').mockReturnValue(0); // low age
        const flash = initializePlayer(p, RACES[0], 'Hero');
        expect(flash.text).toContain(CHARACTER_CONFIG.ageThresholds.labels.youth);
    });

    it('marks as adult when age is between 24 and 54', () => {
        const p = {} as any;
        vi.spyOn(Math, 'random').mockReturnValue(0.35);
        const flash = initializePlayer(p, RACES[0], 'Hero');
        expect(flash.text).toContain(CHARACTER_CONFIG.ageThresholds.labels.adult);
    });

    it('marks as elder when age > 54', () => {
        const p = {} as any;
        vi.spyOn(Math, 'random').mockReturnValue(0.99); // high age
        const flash = initializePlayer(p, RACES[0], 'Hero');
        expect(flash.text).toContain(CHARACTER_CONFIG.ageThresholds.labels.elder);
    });
});

describe('processTick', () => {
    it('heals an Elf (regen 3) with no regen armor by 3 and returns true', () => {
        const p = localPlayer({ raceId: 2, health: 50, armorId: 0 }); // Elf, Peasant's Tunic
        const result = processTick(p);
        expect(result).toBe(true);
        expect(p.health).toBe(53);
        expect(statisticsRepository.increment).toHaveBeenCalledWith('total_hp_regen', 3);
    });

    it('heals a Human (regen 1) with Knight\'s Plate (regen 1) by 2 total and returns true', () => {
        const p = localPlayer({ raceId: 0, health: 70, armorId: 3 }); // Human, Knight's Plate
        const result = processTick(p);
        expect(result).toBe(true);
        expect(p.health).toBe(72);
        expect(statisticsRepository.increment).toHaveBeenCalledWith('total_hp_regen', 2);
    });

    it('returns false and does not heal an Orc (regen 0) with no regen armor', () => {
        const p = localPlayer({ raceId: 1, health: 80, armorId: 0 }); // Orc, Peasant's Tunic
        const result = processTick(p);
        expect(result).toBe(false);
        expect(p.health).toBe(80);
    });

    it('returns false when player is already at full HP', () => {
        const p = localPlayer({ raceId: 2, health: 75, armorId: 0 }); // Elf at max HP (75)
        const result = processTick(p);
        expect(result).toBe(false);
        expect(p.health).toBe(75);
    });

    it('returns false when player is dead', () => {
        const p = localPlayer({ raceId: 2, health: 0, dead: true, armorId: 0 });
        const result = processTick(p);
        expect(result).toBe(false);
        expect(p.health).toBe(0);
    });

    it('clamps HP to maxHp and heals only the remainder', () => {
        const p = localPlayer({ raceId: 0, health: 99, armorId: 0 }); // Human max 100, regen 1
        processTick(p);
        expect(p.health).toBe(100);
        expect(statisticsRepository.increment).toHaveBeenCalledWith('total_hp_regen', 1);
    });

    it('Dark Elf (regen 2) with Eternal Aegis (regen 3) heals for 5 total', () => {
        const p = localPlayer({ raceId: 3, health: 50, armorId: 5 }); // Dark Elf, Eternal Aegis
        processTick(p);
        expect(p.health).toBe(55);
        expect(statisticsRepository.increment).toHaveBeenCalledWith('total_hp_regen', 5);
    });

    it('cleans up expired effects during processTick', () => {
        const p = localPlayer({
            effects: [
                { id: 'expired_buff', type: 'buff', emoji: '⚡', label: 'Expired', expiresAt: Date.now() - 1000, modifiers: [] },
                { id: 'active_buff', type: 'buff', emoji: '🛡️', label: 'Active', expiresAt: Date.now() + 50000, modifiers: [] }
            ]
        });
        const changed = processTick(p);
        expect(changed).toBe(true);
        expect(p.effects?.length).toBe(1);
        expect(p.effects?.[0].id).toBe('active_buff');
    });

    it('clamps current health when maxHealth buff expires and health exceeds base max', () => {
        const p = localPlayer({
            raceId: 0, // Human base max 100
            health: 120, // had food buff previously
            effects: [
                { id: 'expired_food', type: 'buff', emoji: '🍖', label: 'Well Fed', expiresAt: Date.now() - 1000, modifiers: [{ type: 'maxHealth', value: 25 }] }
            ]
        });
        const changed = processTick(p);
        expect(changed).toBe(true);
        expect(p.health).toBe(100);
        expect(p.effects?.length).toBe(0);
    });

    it('cleans up expired buffs and clamps HP while in combat without applying HP regen', () => {
        const p = localPlayer({
            raceId: 2, // Elf base max 75, regen 3
            health: 90, // was at 100 with food buff (75+25), took 10 damage in battle
            effects: [
                { id: 'combat', type: 'aura', emoji: '⚔️', label: 'In Combat', modifiers: [] },
                { id: 'well_fed', type: 'buff', emoji: '🍖', label: 'Well Fed', expiresAt: Date.now() - 500, modifiers: [{ type: 'maxHealth', value: 25 }] }
            ]
        });
        const changed = processTick(p);
        expect(changed).toBe(true);
        // Food buff expired -> removed from effects
        expect(p.effects?.some(e => e.id === 'well_fed')).toBe(false);
        expect(p.effects?.some(e => e.id === 'combat')).toBe(true);
        // Max HP dropped back to 75 -> health clamped to 75 (no regen applied)
        expect(p.health).toBe(75);
    });

    it('does not apply HP regen during tick when in combat with low HP', () => {
        const p = localPlayer({
            raceId: 2, // Elf base max 75, regen 3
            health: 50,
            effects: [
                { id: 'combat', type: 'aura', emoji: '⚔️', label: 'In Combat', modifiers: [] }
            ]
        });
        const changed = processTick(p);
        expect(changed).toBe(false);
        expect(p.health).toBe(50); // No regen during combat
    });

    it('processEffectExpiry cleans expired buffs without applying regen even when wounded', () => {
        const p = localPlayer({
            raceId: 2, // Elf base max 75, regen 3
            health: 50, // wounded
            effects: [
                { id: 'expired_buff', type: 'buff', emoji: '🍎', label: 'Snack', expiresAt: Date.now() - 500, modifiers: [] }
            ]
        });
        const changed = processEffectExpiry(p);
        expect(changed).toBe(true);
        expect(p.effects?.length).toBe(0);
        expect(p.health).toBe(50); // Did NOT heal
    });

    it('processRegenTick reports no change if a maxHealth buff expires mid-call', () => {
        // Defensive guard: getPlayerStats is evaluated once here and again inside restoreHealth.
        // If a +maxHealth buff lapses between the two, the ceiling drops and nothing is actually
        // restored — the tick must then report "no change" rather than a phantom heal.
        const p = localPlayer({ raceId: 0, health: 110 }); // Human: 100 base max
        p.effects = [
            { ...EFFECTS_CONFIG.restingAura },
            { ...EFFECTS_CONFIG.smokedSausage, expiresAt: Date.now() + 1_000 }, // +10 max HP
        ];

        vi.mocked(statisticsRepository.increment).mockClear();
        const realNow = Date.now();
        let call = 0;
        // First read sees the buff alive (max 110); every later read sees it expired (max 100).
        const nowSpy = vi.spyOn(Date, 'now').mockImplementation(() => (call++ === 0 ? realNow : realNow + 10_000));

        try {
            // health 110 < maxHealth 110 is false, so nudge health down to enter the regen path.
            p.health = 109;
            expect(processRegenTick(p)).toBe(false);
            expect(statisticsRepository.increment).not.toHaveBeenCalledWith('total_hp_regen', expect.anything());
        } finally {
            nowSpy.mockRestore();
        }
    });

    it('processRegenTick records only the HP actually restored when capped by max health', () => {
        // Regressions here are invisible in-game but silently inflate the global HP-regen stat:
        // a player one point below maximum heals 1, not their full regen rate.
        const p = localPlayer({ raceId: 2, health: 74, armorId: 0 }); // Elf: 75 max HP, regen 3
        p.effects = [{ ...EFFECTS_CONFIG.restingAura }];

        // This file does not reset mocks between tests, so isolate this call's own increments.
        vi.mocked(statisticsRepository.increment).mockClear();

        expect(processRegenTick(p)).toBe(true);
        expect(p.health).toBe(75);
        expect(statisticsRepository.increment).toHaveBeenCalledWith('total_hp_regen', 1);
        expect(statisticsRepository.increment).not.toHaveBeenCalledWith('total_hp_regen', 3);
    });

    it('processRegenTick heals wounded resting player and returns true', () => {
        const p = localPlayer({
            raceId: 0, // Human base max 100, regen 1
            health: 80,
            effects: [{ ...EFFECTS_CONFIG.restingAura, modifiers: [{ type: 'regen', value: 1 }] }]
        });
        const changed = processRegenTick(p);
        expect(changed).toBe(true);
        expect(p.health).toBe(82); // 80 + 1 (base) + 1 (resting aura)
    });

    it('processEffectExpiry returns false for a dead player, leaving their expired effects untouched', () => {
        // The dead are frozen exactly as they died — no expiry sweep, no maxHealth clamp.
        const p = localPlayer({
            raceId: 2,
            health: 0,
            dead: true,
            effects: [
                { id: 'expired_buff', type: 'buff', emoji: '🍎', label: 'Snack', expiresAt: Date.now() - 500, modifiers: [] }
            ]
        });
        const changed = processEffectExpiry(p);
        expect(changed).toBe(false);
        expect(p.effects?.length).toBe(1); // never swept
    });

    it('processRegenTick returns false for a dead player and never heals them', () => {
        const p = localPlayer({
            raceId: 2, // Elf, regen 3 — would otherwise heal
            health: 0,
            dead: true,
            effects: [{ ...EFFECTS_CONFIG.restingAura }]
        });
        const changed = processRegenTick(p);
        expect(changed).toBe(false);
        expect(p.health).toBe(0);
    });

    it('processTick with applyRegen false only expires effects and does not grant regen', () => {
        const p = localPlayer({
            raceId: 2, // Elf base max 75, regen 3
            health: 50, // wounded
            effects: [
                { id: 'expired_buff', type: 'buff', emoji: '🍎', label: 'Snack', expiresAt: Date.now() - 500, modifiers: [] }
            ]
        });
        const changed = processTick(p, { applyRegen: false });
        expect(changed).toBe(true);
        expect(p.effects?.length).toBe(0);
        expect(p.health).toBe(50); // Remains 50, no unearned regen
    });
});

describe('getRace (internal branch coverage)', () => {
    it('isGameStarted returns false for explicit undefined raceId', () => {
        expect(isGameStarted({ raceId: undefined } as any)).toBe(false);
    });

    it('resolveBattleOutcome returns true for level up', () => {
        const p = localPlayer({ experience: 0, raceId: 0, health: 50 });
        // Level 2: 780 XP
        expect(resolveBattleOutcome(p, { hpLost: 0, xpGained: 780, adenaGained: 0, enemiesKilled: 0, damageBlocked: 0, isCritical: false } as any)).toBe(true);
    });
});

describe('getPlayerStats — regen', () => {
    it('returns race regen + armor regen for Human with Knight\'s Plate', () => {
        const p = localPlayer({ raceId: 0, armorId: 3 }); // Human (regen 1) + Knight's Plate (regen 1)
        expect(getPlayerStats(p).regen).toBe(2);
    });

    it('returns 0 for Orc with no regen armor', () => {
        const p = localPlayer({ raceId: 1, armorId: 0 }); // Orc (regen 0) + Peasant's Tunic (regen 0)
        expect(getPlayerStats(p).regen).toBe(0);
    });

    it('returns armor regen alone when race has 0 regen', () => {
        const p = localPlayer({ raceId: 1, armorId: 3 }); // Orc (regen 0) + Knight's Plate (regen 1)
        expect(getPlayerStats(p).regen).toBe(1);
    });

    it('returns race regen alone when armor has 0 regen', () => {
        const p = localPlayer({ raceId: 2, armorId: 0 }); // Elf (regen 3) + Peasant's Tunic (regen 0)
        expect(getPlayerStats(p).regen).toBe(3);
    });
});

describe('getPlayerStats — crit', () => {
    it('returns race crit + weapon crit for Human with Echos of Valhalla', () => {
        const p = localPlayer({ raceId: 0, weaponId: 3 }); // Human (crit 4) + Echos of Valhalla (crit 3)
        expect(getPlayerStats(p).crit).toBe(7);
    });

    it('returns race crit alone with starter weapon', () => {
        const p = localPlayer({ raceId: 0, weaponId: 0 }); // Human (crit 4) + Apprentice Blade (crit 0)
        expect(getPlayerStats(p).crit).toBe(4);
    });

    it('returns weapon crit alone when race has 0 crit', () => {
        const p = localPlayer({ raceId: 1, weaponId: 3 }); // Orc (crit 0) + Echos of Valhalla (crit 3)
        expect(getPlayerStats(p).crit).toBe(3);
    });

    it('returns 0 when both race and weapon have 0 crit', () => {
        const p = localPlayer({ raceId: 1, weaponId: 0 }); // Orc (crit 0) + Apprentice Blade (crit 0)
        expect(getPlayerStats(p).crit).toBe(0);
    });

    describe('getPlayerStats — attack', () => {
        it('returns the weapon stat for Elven Needle', () => {
            const p = localPlayer({ weaponId: 1 }); // Elven Needle: stat 16
            expect(getPlayerStats(p).attack).toBe(16);
        });

        it('falls back to starter weapon for invalid ID', () => {
            const p = localPlayer({ weaponId: 999 });
            expect(getPlayerStats(p).attack).toBe(7); // Brawler's Fists: stat 7
        });
    });

    describe('getPlayerStats — defense', () => {
        it('returns the armor stat for Brigandine Leathers', () => {
            const p = localPlayer({ armorId: 1 }); // Brigandine Leathers: stat 10
            expect(getPlayerStats(p).defense).toBe(10);
        });

        it('falls back to starter armor for invalid ID', () => {
            const p = localPlayer({ armorId: 999 });
            expect(getPlayerStats(p).defense).toBe(2); // Peasant's Tunic: stat 2
        });
    });
});

describe('getActiveEffects — unknown race/armor ids', () => {
    it('falls back to the default race and armor when computing the resting regen aura', () => {
        // A corrupt or forward-incompatible session must still produce a sane aura rather than
        // throwing on `race.startHealth` / `armor.modifiers` of an undefined catalog entry.
        const p = localPlayer({
            raceId: 99 as unknown as RaceType,
            armorId: 99,
            health: 10,
            effects: [{ ...EFFECTS_CONFIG.restingAura }],
        });

        const effects = getActiveEffects(p);
        const regenerating = effects.find(e => e.id === 'regenerating');

        expect(regenerating).toBeDefined(); // Human fallback: startHealth 100, regen 1
        expect(regenerating?.modifiers).toEqual([{ type: 'regen', value: 1 }]);
    });
});

describe('getActiveEffects — via snapshot', () => {
    it('returns resting aura when resting at full HP', () => {
        const p = localPlayer({
            raceId: 0,
            health: 100,
            effects: [{ ...EFFECTS_CONFIG.restingAura }]
        });
        const effects = getActiveEffects(p);
        expect(effects).toEqual([
            { ...EFFECTS_CONFIG.restingAura }
        ]);
    });

    it('returns resting + regenerating when resting with low HP and regen > 0', () => {
        const p = localPlayer({
            raceId: 2,
            health: 50,
            armorId: 0,
            effects: [{ ...EFFECTS_CONFIG.restingAura }]
        }); // Elf (base regen 3)
        const effects = getActiveEffects(p);
        expect(effects).toEqual([
            { ...EFFECTS_CONFIG.restingAura },
            { ...EFFECTS_CONFIG.regenAura, modifiers: [{ type: 'regen', value: 3 }] },
        ]);
    });

    it('returns only resting (no regenerating) for Orc resting with low HP and 0 total regen', () => {
        const p = localPlayer({
            raceId: 1,
            health: 80,
            armorId: 0,
            effects: [{ ...EFFECTS_CONFIG.restingAura }]
        }); // Orc (base 0 regen, Peasant Tunic 0 regen)
        const effects = getActiveEffects(p);
        expect(effects).toEqual([
            { ...EFFECTS_CONFIG.restingAura }
        ]);
    });

    it('returns resting + regenerating for Orc with Knight Plate (regen 1) when resting with low HP', () => {
        const p = localPlayer({
            raceId: 1,
            health: 80,
            armorId: 3, // Knight's Plate (regen 1)
            effects: [{ ...EFFECTS_CONFIG.restingAura }]
        }); // Orc (base 0 + armor 1 = 1)
        const effects = getActiveEffects(p);
        expect(effects).toEqual([
            { ...EFFECTS_CONFIG.restingAura },
            { ...EFFECTS_CONFIG.regenAura, modifiers: [{ type: 'regen', value: 1 }] },
        ]);
    });

    it('combines aura modifiers into total regen and does not double-count in getPlayerStats', () => {
        const p = localPlayer({
            raceId: 0, // Human base regen 1
            health: 50,
            armorId: 3, // Knight Plate regen 1
            effects: [
                { ...EFFECTS_CONFIG.restingAura, modifiers: [{ type: 'regen', value: 1 }] } // Resting bonus +1
            ]
        });
        const effects = getActiveEffects(p);
        // Total regen = 1 (base) + 1 (armor) + 1 (resting aura) = 3
        expect(effects).toEqual([
            { ...EFFECTS_CONFIG.restingAura, modifiers: [{ type: 'regen', value: 1 }] },
            { ...EFFECTS_CONFIG.regenAura, modifiers: [{ type: 'regen', value: 3 }] },
        ]);

        const stats = getPlayerStats(p);
        expect(stats.regen).toBe(3); // 1 base + 1 armor + 1 resting aura (regenAura not double-counted)
    });

    it('returns resting + regenerating when resting with buffed max health above base startHealth', () => {
        const p = localPlayer({
            raceId: 2, // Elf base maxHp 75, regen 3
            health: 120, // Above base 75, but below buffed 225
            armorId: 0,
            effects: [
                { ...EFFECTS_CONFIG.konamiCheat },
                { ...EFFECTS_CONFIG.restingAura }
            ]
        });
        const effects = getActiveEffects(p);
        expect(effects.some(a => a.id === 'regenerating')).toBe(true);

        // At full 225 HP, regenerating should disappear
        p.health = 225;
        const fullEffects = getActiveEffects(p);
        expect(fullEffects.some(a => a.id === 'regenerating')).toBe(false);
    });

    it('returns combat aura when in combat', () => {
        const p = localPlayer({
            effects: [{ ...EFFECTS_CONFIG.combatAura }]
        });
        const effects = getActiveEffects(p);
        expect(effects).toEqual([{ ...EFFECTS_CONFIG.combatAura }]);
    });

    it('returns empty array when not resting and not in combat', () => {
        const p = localPlayer();
        const effects = getActiveEffects(p);
        expect(effects).toEqual([]);
    });

    it('includes active buffs and debuffs', () => {
        const p = localPlayer();
        applyEffect(p, EFFECTS_CONFIG.smokedSausage);
        const effects = getActiveEffects(p);
        expect(effects.length).toBe(1);
        expect(effects[0].id).toBe('satisfied');
        expect(effects[0].type).toBe('buff');
    });
});

describe('getPlayerStats & applyEffect', () => {
    it('calculates layered stats with base, gear, and active buffs', () => {
        const p = localPlayer({ raceId: 0, weaponId: 1, armorId: 1 }); // Human (base maxHp 100, crit 4, regen 1, ambush 8) + Weapon(16 stat) + Armor(10 stat)
        const statsBase = getPlayerStats(p);
        expect(statsBase.attack).toBe(16);
        expect(statsBase.defense).toBe(10);
        expect(statsBase.crit).toBe(4);
        expect(statsBase.maxHealth).toBe(100);
        expect(statsBase.regen).toBe(1);
        expect(statsBase.ambushRisk).toBe(8);

        // Apply food buff (+30 Max HP)
        applyEffect(p, EFFECTS_CONFIG.heartyMash);

        const statsBuffed = getPlayerStats(p);
        expect(statsBuffed.maxHealth).toBe(130);
    });

    it('applies multiplier modifiers correctly', () => {
        const p = localPlayer();
        applyEffect(p, EFFECTS_CONFIG.konamiCheat);

        const stats = getPlayerStats(p);
        expect(stats.xpMultiplier).toBe(4);
        expect(stats.adenaMultiplier).toBe(4);
        expect(stats.crit).toBe(19); // 4 (base) + 15
    });

    it('filters out expired effects', () => {
        const p = localPlayer();
        p.effects = [
            {
                id: 'expired_buff',
                type: 'buff',
                emoji: '⏳',
                label: 'Expired',
                expiresAt: Date.now() - 1000,
                modifiers: [{ type: 'attack', value: 100 }],
            }
        ];

        const stats = getPlayerStats(p);
        expect(stats.attack).toBe(7); // starter weapon only
    });

    it('clamps stats within valid bounds', () => {
        const p = localPlayer({ raceId: 1, weaponId: 0, armorId: 0 }); // Orc
        applyEffect(p, {
            id: 'curse',
            type: 'debuff',
            emoji: '💀',
            label: 'Heavy Curse',
            modifiers: [
                { type: 'attack', value: -100 },
                { type: 'defense', value: -100 },
                { type: 'crit', value: -50 },
                { type: 'ambushRisk', value: 200 },
            ],
        });

        const stats = getPlayerStats(p);
        expect(stats.attack).toBe(0);
        expect(stats.defense).toBe(0);
        expect(stats.crit).toBe(0);
        expect(stats.ambushRisk).toBe(100);
    });
});

describe('syncZoneAuras', () => {
    it('adds no zone aura when the player is dead', () => {
        const p = localPlayer({ dead: true, effects: [{ ...EFFECTS_CONFIG.restingAura }] });
        syncZoneAuras(p);
        expect(p.effects?.some(e => e.id === 'resting' || e.id === 'combat')).toBe(false);
    });

    it('adds a combat aura when ambushed, with no currentScreen at all', () => {
        const p = localPlayer({ ambushed: true, effects: [] });
        syncZoneAuras(p);
        expect(p.effects?.map(e => e.id)).toEqual(['combat']);
    });

    it.each(TICK_CONFIG.combatZones)('adds a combat aura when currentScreen is "%s" (matches the old game\'s zone.middleware.ts combatZones)', screen => {
        const p = localPlayer({ currentScreen: screen, effects: [] });
        syncZoneAuras(p);
        expect(p.effects?.map(e => e.id)).toEqual(['combat']);
    });

    it.each(TICK_CONFIG.restingZones)('adds a resting aura when currentScreen is "%s" (matches the old game\'s zone.middleware.ts restingZones)', screen => {
        const p = localPlayer({ currentScreen: screen, effects: [] });
        syncZoneAuras(p);
        expect(p.effects?.map(e => e.id)).toEqual(['resting']);
    });

    it.each(['start', 'statistics', 'races', 'error'] as const)('adds no zone aura when currentScreen is "%s" — outside both zone lists, matching the old game\'s behavior for those paths exactly', screen => {
        const p = localPlayer({ currentScreen: screen, effects: [{ ...EFFECTS_CONFIG.restingAura }] });
        syncZoneAuras(p);
        expect(p.effects?.some(e => e.id === 'resting' || e.id === 'combat')).toBe(false);
    });

    it('adds no zone aura when currentScreen has never been reported at all', () => {
        const p = localPlayer({ effects: [] });
        syncZoneAuras(p);
        expect(p.effects?.some(e => e.id === 'resting' || e.id === 'combat')).toBe(false);
    });

    it('ambushed unconditionally forces combat regardless of the reported screen — the safety net a raw socket client can\'t escape by lying about its screen', () => {
        const p = localPlayer({ ambushed: true, currentScreen: 'home', effects: [] });
        syncZoneAuras(p);
        expect(p.effects?.map(e => e.id)).toEqual(['combat']);
    });

    it('replaces a stale zone aura rather than stacking', () => {
        const p = localPlayer({ ambushed: true, effects: [{ ...EFFECTS_CONFIG.restingAura }] });
        syncZoneAuras(p);
        expect(p.effects?.map(e => e.id)).toEqual(['combat']);
    });

    it('preserves non-zone effects untouched', () => {
        const p = localPlayer({ currentScreen: 'home', effects: [{ ...EFFECTS_CONFIG.konamiCheat }] });
        syncZoneAuras(p);
        const ids = p.effects?.map(e => e.id);
        expect(ids).toContain('konami_cheat');
        expect(ids).toContain('resting');
    });

    it('never sets expiresAt on a zone aura — a zone is exactly what the current screen says, never a countdown, matching the old game exactly', () => {
        const combatPlayer = localPlayer({ currentScreen: 'battle', effects: [] });
        syncZoneAuras(combatPlayer);
        expect(combatPlayer.effects?.find(e => e.id === 'combat')?.expiresAt).toBeUndefined();

        const restingPlayer = localPlayer({ currentScreen: 'home', effects: [] });
        syncZoneAuras(restingPlayer);
        expect(restingPlayer.effects?.find(e => e.id === 'resting')?.expiresAt).toBeUndefined();
    });

    describe('return value (Fix 8 — callers need to know whether the aura actually changed)', () => {
        it('returns true on a resting -> combat transition', () => {
            const p = localPlayer({ ambushed: true, effects: [{ ...EFFECTS_CONFIG.restingAura }] });
            expect(syncZoneAuras(p)).toBe(true);
        });

        it('returns true on a combat -> resting transition', () => {
            const p = localPlayer({ ambushed: false, currentScreen: 'home', effects: [{ ...EFFECTS_CONFIG.combatAura }] });
            expect(syncZoneAuras(p)).toBe(true);
        });

        it('returns false when the same aura is recomputed (no actual change)', () => {
            const p = localPlayer({ ambushed: true, effects: [{ ...EFFECTS_CONFIG.combatAura }] });
            expect(syncZoneAuras(p)).toBe(false);
        });

        it('returns false when resting is (re)computed and already present', () => {
            const p = localPlayer({ currentScreen: 'home', effects: [{ ...EFFECTS_CONFIG.restingAura }] });
            expect(syncZoneAuras(p)).toBe(false);
        });

        it('returns true when a live player (with a zone aura present) dies (aura -> neither)', () => {
            const p = localPlayer({ dead: true, effects: [{ ...EFFECTS_CONFIG.combatAura }] });
            expect(syncZoneAuras(p)).toBe(true);
        });

        it('returns false for an already-dead player with no zone aura to begin with', () => {
            const p = localPlayer({ dead: true, effects: [] });
            expect(syncZoneAuras(p)).toBe(false);
        });
    });
});

describe('resetPlayer', () => {
    it('clears game fields so isGameStarted returns false', () => {
        const p = localPlayer({ raceId: 0, health: 100, adena: 500 });
        expect(isGameStarted(p)).toBe(true);
        resetPlayer(p);
        expect(isGameStarted(p)).toBe(false);
    });

    it('deletes name, dead/coward/cheated flags, deathReason, counters, and effects', () => {
        const p = localPlayer({
            dead: true, coward: true, cheated: true, ambushed: true,
            deathReason: 'died', effects: [{ ...EFFECTS_CONFIG.restingAura }],
            revision: 3, currentScreen: 'death',
        });
        resetPlayer(p);

        expect(p.name).toBeUndefined();
        expect(p.raceId).toBeUndefined();
        expect(p.health).toBeUndefined();
        expect(p.adena).toBeUndefined();
        expect(p.experience).toBeUndefined();
        expect(p.weaponId).toBeUndefined();
        expect(p.armorId).toBeUndefined();
        expect(p.dead).toBeUndefined();
        expect(p.ambushed).toBeUndefined();
        expect(p.coward).toBeUndefined();
        expect(p.cheated).toBeUndefined();
        expect(p.deathReason).toBeUndefined();
        expect(p.totalBattles).toBeUndefined();
        expect(p.totalAmbushes).toBeUndefined();
        expect(p.consecutiveAmbushes).toBeUndefined();
        expect(p.totalEnemiesKilled).toBeUndefined();
        expect(p.effects).toBeUndefined();
        expect(p.revision).toBeUndefined();
        expect(p.currentScreen).toBeUndefined();
    });

    it('clears lastBattleNarrative so a restarted character does not show its predecessor\'s last fight', () => {
        const p = localPlayer({
            lastBattleNarrative: {
                narrative: {
                    critLine: null, killLine: 'k', deflectionLine: 'd', outcomeLine: 'o',
                    ambushLine: null, fightPrompt: null, nextMove: 'Strike',
                },
                outcome: { enemiesKilled: 1, hpLost: 1, damageBlocked: 0, xpGained: 1, adenaGained: 1, isCritical: false, isLevelUp: false },
                ambushed: false,
                died: true,
                sound: 'death',
            },
        });
        resetPlayer(p);
        expect(p.lastBattleNarrative).toBeUndefined();
    });

    it('preserves session-store bookkeeping fields (cookie, bootstrappedAt)', () => {
        const p: any = localPlayer({});
        p.cookie = { maxAge: 86400 };
        p.bootstrappedAt = 999;

        resetPlayer(p);

        expect(p.cookie).toEqual({ maxAge: 86400 });
        expect(p.bootstrappedAt).toBe(999);
    });
});

describe('resolveDeathReason', () => {
    it('sets the cheated death reason when player.cheated is true, regardless of coward', () => {
        const p = localPlayer({ cheated: true, coward: true });
        resolveDeathReason(p);
        expect(p.deathReason).toContain('heresy');
    });

    it('sets the same cowardly reason whether or not an ambush was active', () => {
        const p = localPlayer({ coward: true, ambushed: true });
        resolveDeathReason(p);
        expect(p.deathReason).toContain('cowardly way out');
    });

    it('sets the plain coward death reason when coward but not ambushed', () => {
        const p = localPlayer({ coward: true, ambushed: false });
        resolveDeathReason(p);
        expect(p.deathReason).toContain('cowardly way out');
    });

    it('sets a random death message when neither cheated nor coward', () => {
        const p = localPlayer({ cheated: false, coward: false });
        resolveDeathReason(p);
        expect(p.deathReason).toBeDefined();
        expect(DEATH_MESSAGES).toContain(p.deathReason);
    });

    it('is idempotent — never overwrites an already-set deathReason', () => {
        const p = localPlayer({ cheated: true, deathReason: 'Custom Death' });
        resolveDeathReason(p);
        expect(p.deathReason).toBe('Custom Death');
    });
});

describe('killPlayer / commitSuicide — deathReason fixed at time of death', () => {
    it('killPlayer sets a deathReason once, at time of death', () => {
        const p = localPlayer({ health: 75 });
        killPlayer(p);
        expect(p.deathReason).toBeDefined();
    });

    it('commitSuicide sets the coward deathReason (not a random one)', () => {
        const p = localPlayer({ health: 100, ambushed: false });
        commitSuicide(p);
        expect(p.deathReason).toContain('cowardly way out');
    });

    it('commitSuicide while ambushed still reads as an ordinary suicide', () => {
        const p = localPlayer({ health: 100, ambushed: true });
        commitSuicide(p);
        expect(p.deathReason).toContain('cowardly way out');
    });
});
