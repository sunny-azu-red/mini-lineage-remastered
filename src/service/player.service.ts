import { PlayerState, Race, FlashMessage, PurchaseResult, ItemType, BattleResult, PlayerStats, ActiveEffect, EffectConfig, Item, TickOptions } from '@/interface';
import { RACES, ARMORS, WEAPONS, FOODS, EFFECTS_CONFIG, CHARACTER_CONFIG, TICK_CONFIG } from '@/constant/game.constant';
import { isLevelUp, randomInt } from '@/service/math.service';
import { formatAdena, formatNumber, fillTemplate } from '@/util/format.util';
import { randomElement, getItemModifier } from '@/util/game.util';
import { WELCOME_MESSAGES, DEATH_MESSAGES } from '@/constant/narratives.constant';
import { statisticsRepository } from '@/repository/statistics.repository';

export function isGameStarted(player: PlayerState): boolean {
    return player.raceId !== undefined && player.health !== undefined && player.adena !== undefined;
}

export function initializePlayer(player: PlayerState, race: Race, name: string): FlashMessage {
    player.raceId = race.id;
    player.name = name;
    player.health = race.startHealth;
    player.adena = race.startAdena;
    player.experience = 0;
    player.weaponId = 0;
    player.armorId = 0;
    player.totalBattles = 0;
    player.totalAmbushes = 0;
    player.consecutiveAmbushes = 0;
    player.totalEnemiesKilled = 0;
    player.effects = [];

    applyEffect(player, EFFECTS_CONFIG.newbieBuff);
    player.health = getPlayerStats(player).maxHealth;

    void statisticsRepository.increment('total_players');
    void statisticsRepository.increment('total_adena', player.adena);

    const build = randomElement(CHARACTER_CONFIG.builds);
    const age = randomInt(CHARACTER_CONFIG.minAge, CHARACTER_CONFIG.maxAge);
    const definition = age <= CHARACTER_CONFIG.ageThresholds.youth
        ? CHARACTER_CONFIG.ageThresholds.labels.youth
        : (age <= CHARACTER_CONFIG.ageThresholds.adult
            ? CHARACTER_CONFIG.ageThresholds.labels.adult
            : CHARACTER_CONFIG.ageThresholds.labels.elder);
    const welcome = fillTemplate(randomElement(WELCOME_MESSAGES), { raceLabel: race.label });

    const text = `You have chosen the ${race.emoji} ${race.label}, ${welcome}\n` +
        `You are ${build} ${definition} of ${age} seasons, bearing a 🪙 ${formatAdena(player.adena)} Adena tribute.`;

    return { text, type: 'info', sound: 'start' };
}

export function killPlayer(player: PlayerState): void {
    player.health = 0;
    player.dead = true;
    player.effects = [];

    void statisticsRepository.increment('total_deaths');
    resolveDeathReason(player);
}

export function commitSuicide(player: PlayerState): void {
    // set `coward` before killPlayer() so its internal resolveDeathReason() call
    // (idempotent — see below) already sees the correct branch.
    player.coward = true;
    killPlayer(player);
    resolveDeathReason(player);
}

/**
 * Strips existing 'resting'/'combat' zone auras and re-adds the correct one based
 * on current state — server-derived zone tracking (replaces the URL-path-based
 * derivation in zone.middleware.ts). Wired into every `withSession` mutation (see
 * `src/socket/session.ts`) as well as the periodic tick, per the original design.
 * Dead players get neither aura.
 *
 * Returns whether the resting/combat aura actually changed (including a transition
 * to/from "neither", which only happens for dead players) — callers use this to
 * decide whether a zone-only flip needs to persist/broadcast on its own, even when
 * nothing else about the player changed.
 */
export function syncZoneAuras(player: PlayerState): boolean {
    const before = (player.effects ?? []).find(e => e.id === 'resting' || e.id === 'combat')?.id ?? null;

    player.effects = (player.effects ?? []).filter(e => e.id !== 'resting' && e.id !== 'combat');

    if (player.dead)
        return before !== null;

    const inCombat = Boolean(player.ambushed) || (Date.now() - (player.lastFightAt ?? 0)) < TICK_CONFIG.combatLingerMs;

    if (inCombat)
        player.effects.push({ ...EFFECTS_CONFIG.combatAura });
    else
        player.effects.push({ ...EFFECTS_CONFIG.restingAura });

    return before !== (inCombat ? 'combat' : 'resting');
}

/**
 * Clears every PlayerState key back to its "no character" state, preserving
 * session-store bookkeeping fields that aren't part of the game's own fields
 * (`cookie`, `bootstrappedAt`). After this call, isGameStarted(player) is false.
 * Wired into `game:restart` and `highscores:submit` (plan decision A9 — reset in
 * place rather than `req.session.destroy()`).
 */
export function resetPlayer(player: PlayerState): void {
    const gameFields: (keyof PlayerState)[] = [
        'name', 'raceId', 'health', 'adena', 'experience', 'weaponId', 'armorId',
        'dead', 'ambushed', 'coward', 'cheated', 'deathReason',
        'totalBattles', 'totalAmbushes', 'consecutiveAmbushes', 'totalEnemiesKilled',
        'effects', 'revision', 'lastFightAt', 'lastBattleNarrative',
    ];

    for (const key of gameFields)
        delete (player as any)[key];
}

/**
 * Sets player.deathReason (only if not already set) using the same branching
 * as the old renderDeathView — extracted here so the reason is fixed once, at
 * time of death, rather than re-randomized on every render.
 */
export function resolveDeathReason(player: PlayerState): void {
    if (player.deathReason)
        return;

    if (player.cheated)
        player.deathReason = "👾 The gods saw your heresy and cast your memory into oblivion.";
    else if (player.coward)
        player.deathReason = player.ambushed
            ? "🪤 You were caught trying to flee an ambush!"
            : "🤡 You took the cowardly way out.";
    else
        player.deathReason = randomElement(DEATH_MESSAGES);
}

export function deductCost(player: PlayerState, cost: number): boolean {
    if (player.adena < cost)
        return false;

    player.adena -= cost;

    return true;
}

/**
 * Gathers all active effects (state auras + active buffs/debuffs).
 */
export function getActiveEffects(player: PlayerState): ActiveEffect[] {
    if (player.dead)
        return [];

    const now = Date.now();
    const effects: ActiveEffect[] = [];

    let hasResting = false;
    let effectMaxHealthBonus = 0;
    let effectRegenBonus = 0;

    // Timed Buffs / Debuffs & Permanent Curses / State Auras
    for (const effect of player.effects ?? []) {
        if (effect.expiresAt === undefined || effect.expiresAt > now) {
            effects.push(effect);
            if (effect.id === 'resting')
                hasResting = true;
            for (const mod of effect.modifiers) {
                if (mod.type === 'maxHealth')
                    effectMaxHealthBonus += mod.value;
                else if (mod.type === 'regen')
                    effectRegenBonus += mod.value;
            }
        }
    }

    // Dynamic Regenerating aura when resting below effective max HP with > 0 total regen
    if (hasResting) {
        const race = RACES[player.raceId] ?? RACES[0];
        const armor = ARMORS[player.armorId] ?? ARMORS[0];
        const effectiveMaxHealth = Math.max(1, race.startHealth + effectMaxHealthBonus);
        const totalRegen = Math.max(0, race.regen + (getItemModifier(armor, 'regen') ?? 0) + effectRegenBonus);

        if (player.health < effectiveMaxHealth && totalRegen > 0) {
            effects.push({
                ...EFFECTS_CONFIG.regenAura,
                modifiers: [{ type: 'regen', value: totalRegen }],
            });
        }
    }

    return effects;
}

/**
 * Pure layered computation pipeline that calculates the player's effective stats.
 */
export function getPlayerStats(player: PlayerState): PlayerStats {
    const race = RACES[player.raceId] ?? RACES[0];
    const weapon = WEAPONS[player.weaponId] ?? WEAPONS[0];
    const armor = ARMORS[player.armorId] ?? ARMORS[0];
    const activeEffects = getActiveEffects(player);

    // Tier 1: Base Ancestry
    const stats: PlayerStats = {
        attack: 0,
        defense: 0,
        crit: race.crit,
        maxHealth: race.startHealth,
        regen: race.regen,
        ambushRisk: race.ambushChance,
        xpMultiplier: 1.0,
        adenaMultiplier: 1.0,
    };

    // Tier 2: Equipment Base Stats
    stats.attack += weapon.stat;
    stats.defense += armor.stat;

    // Tier 3: Modifiers (Equipment & Active Effects combined)
    const modifiers = [
        ...(weapon.modifiers ?? []),
        ...(armor.modifiers ?? []),
        ...activeEffects.filter(e => e.id !== 'regenerating').flatMap(e => e.modifiers),
    ];

    for (const mod of modifiers) {
        if (mod.type === 'xpMultiplier' || mod.type === 'adenaMultiplier')
            stats[mod.type] *= mod.value;
        else
            stats[mod.type] += mod.value;
    }

    // Tier 4: Sanitization & Range Bounds
    stats.attack = Math.max(0, stats.attack);
    stats.defense = Math.max(0, stats.defense);
    stats.crit = Math.max(0, Math.min(100, stats.crit));
    stats.regen = Math.max(0, stats.regen);
    stats.maxHealth = Math.max(1, stats.maxHealth);
    stats.ambushRisk = Math.max(0, Math.min(100, stats.ambushRisk));
    stats.xpMultiplier = Math.max(0, stats.xpMultiplier);
    stats.adenaMultiplier = Math.max(0, stats.adenaMultiplier);

    return stats;
}

/**
 * Applies a buff, debuff, or permanent effect to the player.
 * If the effect belongs to a group (e.g. 'food'), any existing active effect in the same group is replaced.
 */
export function applyEffect(
    player: PlayerState,
    effect: EffectConfig
): void {
    const now = Date.now();

    const existing = (player.effects ?? []).filter(e => {
        if (effect.group && e.group === effect.group)
            return false;

        return e.id !== effect.id && (e.expiresAt === undefined || e.expiresAt > now);
    });

    const newEffect: ActiveEffect = {
        id: effect.id,
        type: effect.type,
        group: effect.group,
        emoji: effect.emoji,
        label: effect.label,
        modifiers: effect.modifiers,
        expiresAt: effect.durationMs ? now + effect.durationMs : undefined,
    };

    existing.push(newEffect);
    player.effects = existing;
}

export function restoreHealth(player: PlayerState, amount: number): number {
    const stats = getPlayerStats(player);
    const oldHealth = player.health;
    player.health = Math.min(stats.maxHealth, player.health + amount);

    return player.health - oldHealth;
}

export function resolveBattleOutcome(player: PlayerState, result: BattleResult): boolean {
    let { hpLost, xpGained, adenaGained, enemiesKilled, damageBlocked, isCritical } = result;

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
        const stats = getPlayerStats(player);
        const hpHealed = restoreHealth(player, stats.maxHealth);
        void statisticsRepository.increment('total_levels_gained');
        void statisticsRepository.increment('total_hp_healed', hpHealed);

        return true;
    }

    return false;
}

export function purchaseItem(player: PlayerState, itemType: ItemType, itemId: number): PurchaseResult | null {
    const item: Item | undefined = itemType === ItemType.Weapon ? WEAPONS[itemId] : (itemType === ItemType.Armor ? ARMORS[itemId] : FOODS[itemId]);
    if (!item)
        return null;

    if (itemType === ItemType.Weapon && player.weaponId === itemId)
        return { success: false, text: `You are already wielding the ${item.emoji} ${item.name}!`, item };
    if (itemType === ItemType.Armor && player.armorId === itemId)
        return { success: false, text: `You are already wearing the ${item.emoji} ${item.name}!`, item };
    if (!deductCost(player, item.cost))
        return { success: false, text: `You do not have enough Adena to buy ${item.emoji} ${item.name}!`, item };

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
        if (item.effect)
            applyEffect(player, item.effect);

        const hpHealed = restoreHealth(player, item.stat);
        void statisticsRepository.increment('total_food_bought');
        void statisticsRepository.increment('total_adena_spent', item.cost);
        void statisticsRepository.increment('total_hp_healed', hpHealed);

        const effectDesc = item.effect ? `\nYou feel invigorated by the ${item.effect.emoji} ${item.effect.label} buff!` : '';

        return { success: true, text: `You have bought ${item.emoji} ${item.name}.${effectDesc}\nYou feel your strength returning, bringing you to ${formatNumber(player.health)} HP.`, item };
    }
}

/**
 * Returns the player's total attack power.
 */
export function getTotalAttack(player: PlayerState): number {
    return getPlayerStats(player).attack;
}

/**
 * Returns the player's total defense value.
 */
export function getTotalDefense(player: PlayerState): number {
    return getPlayerStats(player).defense;
}

/**
 * Returns the player's total HP regeneration per tick.
 */
export function getTotalRegen(player: PlayerState): number {
    return getPlayerStats(player).regen;
}

/**
 * Returns the player's total critical hit chance.
 */
export function getTotalCrit(player: PlayerState): number {
    return getPlayerStats(player).crit;
}

/**
 * Gathers active status effects for a player based on their current state.
 */
export function getPlayerEffects(player: PlayerState): ActiveEffect[] {
    return getActiveEffects(player);
}

/**
 * Processes effect expiration and clamps current health to max health if a maxHealth buff expired.
 * Runs on exact expiration timeouts as well as routine periodic ticks.
 * Does NOT perform HP regeneration.
 *
 * Returns true if effects expired or current health was clamped.
 */
export function processEffectExpiry(player: PlayerState): boolean {
    if (player.dead)
        return false;

    let stateChanged = false;
    const now = Date.now();

    // 1. Clean up expired effects
    if (player.effects && player.effects.length > 0) {
        const remaining = player.effects.filter(e => e.expiresAt === undefined || e.expiresAt > now);
        if (remaining.length !== player.effects.length) {
            player.effects = remaining;
            stateChanged = true;
        }
    }

    const stats = getPlayerStats(player);

    // 2. Clamp current health if a maxHealth buff expired
    if (player.health > stats.maxHealth) {
        player.health = stats.maxHealth;
        stateChanged = true;
    }

    return stateChanged;
}

/**
 * Applies natural HP regeneration for players outside combat.
 * Runs strictly on the periodic cadence (TICK_CONFIG.intervalMs = 5000ms).
 *
 * Returns true if health was restored.
 */
export function processRegenTick(player: PlayerState): boolean {
    if (player.dead)
        return false;

    const inCombat = player.effects?.some(e => e.id === 'combat');
    if (inCombat)
        return false;

    const stats = getPlayerStats(player);
    if (stats.regen > 0 && player.health < stats.maxHealth) {
        const healed = restoreHealth(player, stats.regen);
        if (healed > 0) {
            void statisticsRepository.increment('total_hp_regen', healed);

            return true;
        }
    }

    return false;
}

/**
 * processTick — entry point for passive state processing.
 *
 * @param player The player state to process
 * @param options.applyRegen Whether to apply natural HP regeneration (default: true for periodic ticks, false for discrete expiry events)
 */
export function processTick(player: PlayerState, options: TickOptions = {}): boolean {
    if (player.dead)
        return false;

    const applyRegen = options.applyRegen ?? true;
    const expiryChanged = processEffectExpiry(player);
    const regenChanged = applyRegen ? processRegenTick(player) : false;

    return expiryChanged || regenChanged;
}
