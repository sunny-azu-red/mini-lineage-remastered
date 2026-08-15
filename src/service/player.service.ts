import { PlayerState, Race, FlashMessage, PurchaseResult, ItemType, BattleResult } from '@/interface';
import { RACES, ARMORS, WEAPONS, FOODS } from '@/constant/game.constant';
import { isLevelUp, randomInt } from '@/service/math.service';
import { formatAdena, formatNumber, fillTemplate } from '@/util/format.util';
import { randomElement } from '@/util/game.util';
import { WELCOME_MESSAGES } from '@/constant/narratives.constant';
import { statisticsRepository } from '@/repository/statistics.repository';

export function isGameStarted(player: PlayerState): boolean {
    return player.raceId !== undefined && player.health !== undefined && player.adena !== undefined;
}

export function initializePlayer(player: PlayerState, race: Race, name: string): FlashMessage {
    player.raceId = race.id;
    player.name = name;
    player.health = race.startHealth;
    player.prevHealth = 0;
    player.adena = race.startAdena;
    player.prevAdena = 0;
    player.experience = 0;
    player.prevExperience = 0;
    player.weaponId = 0;
    player.armorId = 0;
    player.totalBattles = 0;
    player.totalAmbushes = 0;
    player.totalEnemiesKilled = 0;

    void statisticsRepository.increment('total_players');
    void statisticsRepository.increment('total_adena', player.adena);

    const builds = ['a hardy', 'a wiry', 'a sturdy', 'a fit', 'a rugged', 'a robust', 'a solid'];
    const build = randomElement(builds);
    const age = randomInt(9, 69);
    const definition = age <= 23 ? 'youth' : (age <= 54 ? 'adult' : 'elder');
    const welcome = fillTemplate(randomElement(WELCOME_MESSAGES), { raceLabel: race.label });

    const text = `You have chosen the ${race.emoji} ${race.label}, ${welcome}\n` +
        `You are ${build} ${definition} of ${age} seasons, bearing a 🪙 ${formatAdena(player.adena)} Adena tribute.`;

    return { text, type: 'info' };
}

export function killPlayer(player: PlayerState): void {
    player.health = 0;
    player.dead = true;

    void statisticsRepository.increment('total_deaths');
}

export function commitSuicide(player: PlayerState): void {
    killPlayer(player);
    player.coward = true;
}

export function deductCost(player: PlayerState, cost: number): boolean {
    if (player.adena < cost)
        return false;

    player.adena -= cost;
    return true;
}

export function restoreHealth(player: PlayerState, amount: number): number {
    const maxHp = RACES[player.raceId].startHealth;
    const oldHealth = player.health;
    player.health = Math.min(maxHp, player.health + amount);
    return player.health - oldHealth;
}

export function resolveBattleOutcome(player: PlayerState, result: BattleResult): boolean {
    let { hpLost, xpGained, adenaGained, enemiesKilled, damageBlocked, isCritical } = result;

    // hpLost = 0; // DEBUG: never die
    // xpGained = xpGained * 250; // DEBUG: level up faster
    // adenaGained = adenaGained * 500; // DEBUG: get adena faster

    player.health -= hpLost;
    if (player.health <= 0) {
        killPlayer(player);
        return false;
    }

    player.adena += adenaGained;
    const oldXp = player.experience;
    player.experience += xpGained;
    player.totalBattles = (player.totalBattles ?? 0) + 1;
    player.totalEnemiesKilled = (player.totalEnemiesKilled ?? 0) + enemiesKilled;

    if (isCritical)
        void statisticsRepository.increment('total_critical_hits');

    void statisticsRepository.increment('total_battles');
    void statisticsRepository.increment('total_enemies_killed', enemiesKilled);
    void statisticsRepository.increment('total_adena_generated', adenaGained);
    void statisticsRepository.increment('total_adena', adenaGained);
    void statisticsRepository.increment('total_hp_lost', hpLost);
    void statisticsRepository.increment('total_xp_gained', xpGained);
    void statisticsRepository.increment('total_damage_blocked', damageBlocked);

    if (isLevelUp(oldXp, player.experience)) {
        const hpHealed = restoreHealth(player, RACES[player.raceId].startHealth);
        void statisticsRepository.increment('total_levels_gained');
        void statisticsRepository.increment('total_hp_healed', hpHealed);
        return true;
    }

    return false;
}

export function purchaseItem(player: PlayerState, itemType: ItemType, itemId: number): PurchaseResult | null {
    const item = itemType === ItemType.Weapon ? WEAPONS[itemId] : (itemType === ItemType.Armor ? ARMORS[itemId] : FOODS[itemId]);
    if (!item)
        return null;

    if (itemType === ItemType.Weapon && player.weaponId === itemId)
        return { success: false, text: `Sorry, you already own the ${item.emoji} ${item.name}.`, item };
    if (itemType === ItemType.Armor && player.armorId === itemId)
        return { success: false, text: `Sorry, you already own the ${item.emoji} ${item.name}.`, item };

    if (!deductCost(player, item.cost))
        return { success: false, text: 'Sorry, you need more 🪙 Adena.' };

    if (itemType === ItemType.Weapon) {
        player.weaponId = itemId;
        void statisticsRepository.increment('total_weapons_bought');
        void statisticsRepository.increment('total_adena_spent', item.cost);
        return { success: true, text: `You have bought a Weapon.\nYou are now wielding the swift ${item.emoji} ${item.name}!`, item };
    } else if (itemType === ItemType.Armor) {
        player.armorId = itemId;
        void statisticsRepository.increment('total_armors_bought');
        void statisticsRepository.increment('total_adena_spent', item.cost);
        return { success: true, text: `You have bought an Armor.\nYou are now wearing the mighty ${item.emoji} ${item.name}!`, item };
    } else {
        const hpHealed = restoreHealth(player, item.stat);
        void statisticsRepository.increment('total_food_bought');
        void statisticsRepository.increment('total_adena_spent', item.cost);
        void statisticsRepository.increment('total_hp_healed', hpHealed);
        return { success: true, text: `You have bought ${item.emoji} ${item.name}.\nYou feel your strength returning, bringing you to ${formatNumber(player.health)} HP.`, item };
    }
}

/**
 * Returns the player's total attack power (currently just the weapon stat).
 */
export function getTotalAttack(player: PlayerState): number {
    const weapon = WEAPONS[player.weaponId] || WEAPONS[0];
    return weapon.stat;
}

/**
 * Returns the player's total defense value (currently just the armor stat).
 */
export function getTotalDefense(player: PlayerState): number {
    const armor = ARMORS[player.armorId] || ARMORS[0];
    return armor.stat;
}

/**
 * Returns the player's total HP regeneration per tick (race base + armor bonus).
 */
export function getTotalRegen(player: PlayerState): number {
    const race = RACES[player.raceId];
    const armor = ARMORS[player.armorId];
    return (race?.regen ?? 0) + (armor?.regen ?? 0);
}

/**
 * Returns the player's total critical hit chance (race base + weapon bonus).
 */
export function getTotalCrit(player: PlayerState): number {
    const race = RACES[player.raceId];
    const weapon = WEAPONS[player.weaponId];
    return (race?.crit ?? 0) + (weapon?.crit ?? 0);
}

/**
 * Gathers active status effects (auras) for a player based on their current state.
 * This can be easily extended with more complex logic (e.g., duration-based buffs).
 */
export function getPlayerAuras(player: PlayerState) {
    const auras = [];

    if (player.isResting) {
        auras.push({ id: 'resting', icon: '⛺', label: 'Resting' });

        const maxHp = RACES[player.raceId]?.startHealth ?? 0;
        if (player.health < maxHp && getTotalRegen(player) > 0)
            auras.push({ id: 'regenerating', icon: '🌿', label: 'Regenerating' });
    }

    if (player.inCombat && !player.dead)
        auras.push({ id: 'combat', icon: '⚔️', label: 'In Combat' });

    return auras;
}

/**
 * processTick — entry point for all time-based passive effects (regen, future buffs/debuffs).
 * Called by SocketService on every TICK_CONFIG.intervalMs tick.
 *
 * Returns true if the player state was modified (so the socket knows to emit).
 */
export function processTick(player: PlayerState): boolean {
    if (player.dead)
        return false;

    const totalRegen = getTotalRegen(player);
    if (totalRegen <= 0)
        return false;

    const healed = restoreHealth(player, totalRegen);
    if (healed <= 0)
        return false;

    player.prevHealth = player.health;

    void statisticsRepository.increment('total_hp_regen', healed);
    return true;
}
