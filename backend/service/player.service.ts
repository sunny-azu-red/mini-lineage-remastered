import { PlayerState, Race, FlashMessage, PurchaseResult, ItemType, BattleResult, PlayerStats, ActiveEffect, EffectConfig, Item, StatField } from '@/interface';
import { RACES, ARMORS, WEAPONS, FOODS, EFFECTS_CONFIG, CHARACTER_CONFIG, ZONE_CONFIG } from '@/constant/game.constant';
import { isLevelUp, randomInt } from '@/service/math.service';
import { formatAdena, formatNumber, fillTemplate } from '@/util/format.util';
import { randomElement } from '@/util/game.util';
import { WELCOME_MESSAGES, DEATH_MESSAGES } from '@/constant/narratives.constant';
import { statisticsRepository } from '@/repository/statistics.repository';

const ZONE_AURA_IDS = ['resting', 'combat'];

/** Every PlayerState key `resetPlayer` clears — i.e. everything except session-store bookkeeping. */
const GAME_FIELDS: (keyof PlayerState)[] = [
    'name', 'raceId', 'health', 'adena', 'experience', 'weaponId', 'armorId',
    'dead', 'ambushed', 'coward', 'cheated', 'deathReason',
    'totalBattles', 'totalAmbushes', 'consecutiveAmbushes', 'totalEnemiesKilled',
    'effects', 'revision', 'currentScreen', 'combatUntil', 'lastBattleNarrative',
];

export function isGameStarted(player: PlayerState): boolean {
    return player.raceId !== undefined && player.health !== undefined && player.adena !== undefined;
}

export function initializePlayer(player: PlayerState, race: Race, name: string): FlashMessage {
    Object.assign(player, {
        raceId: race.id, name, health: race.startHealth, adena: race.startAdena,
        experience: 0, weaponId: 0, armorId: 0,
        totalBattles: 0, totalAmbushes: 0, consecutiveAmbushes: 0, totalEnemiesKilled: 0,
        effects: [],
    });

    applyEffect(player, EFFECTS_CONFIG.newbieBuff);
    player.health = getPlayerStats(player).maxHealth;

    void statisticsRepository.increment('total_players');
    void statisticsRepository.increment('total_adena', player.adena);

    // Draw order is load-bearing only in that it must stay stable: build, then age, then welcome.
    const { minAge, maxAge, ageThresholds: { youth, adult, labels }, builds } = CHARACTER_CONFIG;
    const build = randomElement(builds);
    const age = randomInt(minAge, maxAge);
    const definition = age <= youth ? labels.youth : age <= adult ? labels.adult : labels.elder;
    const welcome = fillTemplate(randomElement(WELCOME_MESSAGES), { raceLabel: race.label });

    return {
        text: `You have chosen the ${race.emoji} ${race.label}, ${welcome}\n` +
            `You are ${build} ${definition} of ${age} seasons, bearing a 🪙 ${formatAdena(player.adena)} Adena tribute.`,
        type: 'info',
        sound: 'start',
    };
}

export function killPlayer(player: PlayerState): void {
    player.health = 0;
    player.dead = true;
    player.effects = [];

    void statisticsRepository.increment('total_deaths');
    resolveDeathReason(player);
}

export function commitSuicide(player: PlayerState): void {
    // `coward` must be set BEFORE killPlayer, whose resolveDeathReason call picks the branch.
    player.coward = true;
    killPlayer(player);
}

/**
 * Actively held in combat: standing in a combat zone, or ambushed anywhere. `ambushed` counts
 * unconditionally, so a raw socket client lying about its screen can never escape an ambush.
 */
function isHeldInCombat(player: PlayerState): boolean {
    const screen = player.currentScreen;

    return Boolean(player.ambushed) || (screen !== undefined && ZONE_CONFIG.combatZones.includes(screen));
}

/**
 * The zone aura the player should have right now, or null for a screen in neither zone list.
 *
 * `before` is the aura being replaced, and is what makes the disengage transition detectable
 * without a second bookkeeping field: an indefinite combat aura (no `expiresAt`) means the player
 * was standing in a combat zone on the previous sync, so if they no longer are, they just stepped
 * out and the countdown starts now.
 */
function resolveZoneAura(player: PlayerState, before: ActiveEffect | undefined): ActiveEffect | null {
    const now = Date.now();

    if (isHeldInCombat(player)) {
        // Standing in it: combat is indefinite, and any pending disengage is void. This is what
        // keeps regen paused forever on the battleground no matter how much time passes.
        delete player.combatUntil;

        return { ...EFFECTS_CONFIG.combatAura };
    }

    if (before?.id === 'combat' && before.expiresAt === undefined)
        player.combatUntil = now + ZONE_CONFIG.combatLingerMs;

    // Disengaging: still in combat, but now counting down. Re-entering a combat zone cancels it
    // (above), and leaving again arms a fresh one — deliberate, since the countdown is anchored
    // to leaving the zone rather than to the last fight.
    if (player.combatUntil !== undefined && player.combatUntil > now)
        return { ...EFFECTS_CONFIG.combatAura, expiresAt: player.combatUntil };

    delete player.combatUntil;

    const screen = player.currentScreen;

    return screen !== undefined && ZONE_CONFIG.restingZones.includes(screen)
        ? { ...EFFECTS_CONFIG.restingAura }
        : null;
}

/**
 * Re-derives the resting/combat zone aura from `currentScreen` (stamped by `player:screen`),
 * returning whether it changed. Dead players and screens in neither zone list get no aura.
 *
 * The resting aura never carries an `expiresAt`; the combat aura carries one only while
 * disengaging, which is how the countdown reaches the client — as an ordinary effect expiry, so
 * `syncExpiryTimers` schedules its exact wake-up and `EffectIcon` renders its timer for free.
 *
 * The returned "changed" flag compares `expiresAt` as well as the id, because combat gaining a
 * countdown is a real change that callers must persist and broadcast.
 */
export function syncZoneAuras(player: PlayerState): boolean {
    const effects = player.effects ?? [];
    const before = effects.find(e => ZONE_AURA_IDS.includes(e.id));
    player.effects = effects.filter(e => !ZONE_AURA_IDS.includes(e.id));

    const after = player.dead ? null : resolveZoneAura(player, before);
    if (after)
        player.effects.push(after);

    return before?.id !== after?.id || before?.expiresAt !== after?.expiresAt;
}

/** Clears every game field, preserving session-store bookkeeping (`cookie`, `bootstrappedAt`). */
export function resetPlayer(player: PlayerState): void {
    for (const key of GAME_FIELDS)
        delete (player as Partial<PlayerState>)[key];
}

/** Fixes the death reason once, at time of death, so it is never re-randomized on re-render. */
export function resolveDeathReason(player: PlayerState): void {
    if (player.deathReason)
        return;

    // There is no "caught fleeing an ambush" reason any more: fleeing is prevented rather than
    // punished, so the event that message described cannot occur. A player who quits while
    // ambushed simply quit.
    player.deathReason = player.cheated
        ? '👾 The gods saw your heresy and cast your memory into oblivion.'
        : player.coward
            ? '🤡 You took the cowardly way out.'
            : randomElement(DEATH_MESSAGES);
}

export function deductCost(player: PlayerState, cost: number): boolean {
    if (player.adena < cost)
        return false;

    player.adena -= cost;

    return true;
}

/** All currently active effects: unexpired buffs/debuffs/auras, plus the dynamic regen aura. */
export function getActiveEffects(player: PlayerState): ActiveEffect[] {
    if (player.dead)
        return [];

    const now = Date.now();
    const effects = (player.effects ?? []).filter(e => e.expiresAt === undefined || e.expiresAt > now);

    if (!effects.some(e => e.id === 'resting'))
        return effects;

    // Regenerating aura: only while resting, wounded, and with a positive total regen rate.
    // The modifier list mirrors getPlayerStats' exactly — it cannot just call that, which would
    // recurse back into here, so equipment is folded in rather than partially special-cased.
    // Summing max health from effects alone agreed with getPlayerStats only by luck: no weapon
    // or armor carries a maxHealth modifier today, but ItemView exposes one and the shop renders
    // it, so the first item that did would hide this aura from a genuinely wounded player.
    const race = RACES[player.raceId] ?? RACES[0];
    const weapon = WEAPONS[player.weaponId] ?? WEAPONS[0];
    const armor = ARMORS[player.armorId] ?? ARMORS[0];

    const allModifiers = [...(weapon.modifiers ?? []), ...(armor.modifiers ?? []), ...effects.flatMap(e => e.modifiers)];
    const sumMod = (type: 'maxHealth' | 'regen') =>
        allModifiers.reduce((total, m) => total + (m.type === type ? m.value : 0), 0);

    const effectiveMaxHealth = Math.max(1, race.startHealth + sumMod('maxHealth'));
    const totalRegen = Math.max(0, race.regen + sumMod('regen'));

    if (player.health < effectiveMaxHealth && totalRegen > 0)
        effects.push({ ...EFFECTS_CONFIG.regenAura, modifiers: [{ type: 'regen', value: totalRegen }] });

    return effects;
}

/** Layered pipeline: race base -> equipment stats -> equipment/effect modifiers -> clamps. */
export function getPlayerStats(player: PlayerState): PlayerStats {
    const race = RACES[player.raceId] ?? RACES[0];
    const weapon = WEAPONS[player.weaponId] ?? WEAPONS[0];
    const armor = ARMORS[player.armorId] ?? ARMORS[0];

    const stats: PlayerStats = {
        attack: weapon.stat,
        defense: armor.stat,
        crit: race.crit,
        maxHealth: race.startHealth,
        regen: race.regen,
        ambushRisk: race.ambushChance,
        xpMultiplier: 1.0,
        adenaMultiplier: 1.0,
    };

    const modifiers = [
        ...(weapon.modifiers ?? []),
        ...(armor.modifiers ?? []),
        // 'regenerating' is derived FROM regen, so folding it back in would double-count.
        ...getActiveEffects(player).filter(e => e.id !== 'regenerating').flatMap(e => e.modifiers),
    ];

    for (const mod of modifiers) {
        if (mod.type === 'xpMultiplier' || mod.type === 'adenaMultiplier')
            stats[mod.type] *= mod.value;
        else
            stats[mod.type] += mod.value;
    }

    const clamp = (v: number, min: number, max = Infinity) => Math.max(min, Math.min(max, v));
    stats.attack = clamp(stats.attack, 0);
    stats.defense = clamp(stats.defense, 0);
    stats.crit = clamp(stats.crit, 0, 100);
    stats.regen = clamp(stats.regen, 0);
    stats.maxHealth = clamp(stats.maxHealth, 1);
    stats.ambushRisk = clamp(stats.ambushRisk, 0, 100);
    stats.xpMultiplier = clamp(stats.xpMultiplier, 0);
    stats.adenaMultiplier = clamp(stats.adenaMultiplier, 0);

    return stats;
}

/** Applies an effect, replacing any active effect sharing its id or its `group` (e.g. 'food'). */
export function applyEffect(player: PlayerState, effect: EffectConfig): void {
    const now = Date.now();
    const kept = (player.effects ?? []).filter(e =>
        !(effect.group && e.group === effect.group) &&
        e.id !== effect.id &&
        (e.expiresAt === undefined || e.expiresAt > now));

    kept.push({
        id: effect.id,
        type: effect.type,
        group: effect.group,
        emoji: effect.emoji,
        label: effect.label,
        modifiers: effect.modifiers,
        expiresAt: effect.durationMs ? now + effect.durationMs : undefined,
    });

    player.effects = kept;
}

/** Heals up to max HP; returns how much was actually restored. */
export function restoreHealth(player: PlayerState, amount: number): number {
    const before = player.health;
    player.health = Math.min(getPlayerStats(player).maxHealth, player.health + amount);

    return player.health - before;
}

/** Applies a resolved fight to the player. Returns whether it caused a level-up. */
export function resolveBattleOutcome(player: PlayerState, result: BattleResult): boolean {
    const { hpLost, xpGained, adenaGained, enemiesKilled, damageBlocked, isCritical } = result;

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

    if (!isLevelUp(oldXp, player.experience))
        return false;

    const hpHealed = restoreHealth(player, getPlayerStats(player).maxHealth);
    void statisticsRepository.increment('total_levels_gained');
    void statisticsRepository.increment('total_hp_healed', hpHealed);

    return true;
}

interface EquipmentSlot {
    items: readonly Item[];
    slot: 'weaponId' | 'armorId';
    stat: StatField;
    owned: (item: Item) => string;
    bought: (item: Item) => string;
}

/**
 * Null-prototype so an unexpected `itemType` can never resolve to an inherited `Object.prototype`
 * member (`constructor`, `toString`, …) and be treated as a real equipment slot.
 */
const EQUIPMENT: Record<string, EquipmentSlot | undefined> = Object.assign(Object.create(null), {
    [ItemType.Weapon]: {
        items: WEAPONS as readonly Item[],
        slot: 'weaponId' as const,
        stat: 'total_weapons_bought' as StatField,
        owned: (i: Item) => `You are already wielding the ${i.emoji} ${i.name}!`,
        bought: (i: Item) => `You have bought a Weapon.\nYou are now wielding the swift ${i.emoji} ${i.name}!`,
    },
    [ItemType.Armor]: {
        items: ARMORS as readonly Item[],
        slot: 'armorId' as const,
        stat: 'total_armors_bought' as StatField,
        owned: (i: Item) => `You are already wearing the ${i.emoji} ${i.name}!`,
        bought: (i: Item) => `You have bought an Armor.\nYou are now wearing the mighty ${i.emoji} ${i.name}!`,
    },
});

/** Returns null for an unknown item; a `success: false` result for a rejected-but-valid purchase. */
export function purchaseItem(player: PlayerState, itemType: ItemType, itemId: number): PurchaseResult | null {
    const equipment = EQUIPMENT[itemType];
    const item: Item | undefined = (equipment?.items ?? FOODS)[itemId];
    if (!item)
        return null;

    if (equipment && player[equipment.slot] === itemId)
        return { success: false, text: equipment.owned(item), item };
    if (!deductCost(player, item.cost))
        return { success: false, text: `You do not have enough Adena to buy ${item.emoji} ${item.name}!`, item };

    void statisticsRepository.increment('total_adena_spent', item.cost);

    if (equipment) {
        player[equipment.slot] = itemId;
        void statisticsRepository.increment(equipment.stat);

        return { success: true, text: equipment.bought(item), item };
    }

    if (item.effect)
        applyEffect(player, item.effect);

    const hpHealed = restoreHealth(player, item.stat);
    void statisticsRepository.increment('total_food_bought');
    void statisticsRepository.increment('total_hp_healed', hpHealed);

    const buff = item.effect ? `\nYou feel invigorated by the ${item.effect.emoji} ${item.effect.label} buff!` : '';

    return {
        success: true,
        text: `You have bought ${item.emoji} ${item.name}.${buff}\nYou feel your strength returning, bringing you to ${formatNumber(player.health)} HP.`,
        item,
    };
}

/**
 * Drops expired effects and clamps health if a maxHealth buff went away. Returns whether anything
 * changed. Driven ONLY by each effect's own exact-expiry timer (see emitter.ts::syncExpiryTimers) —
 * the periodic loop is the regen cadence and no longer sweeps effects. Never regenerates.
 */
export function processEffectExpiry(player: PlayerState): boolean {
    if (player.dead)
        return false;

    const now = Date.now();
    const remaining = (player.effects ?? []).filter(e => e.expiresAt === undefined || e.expiresAt > now);
    let changed = remaining.length !== (player.effects?.length ?? 0);
    if (changed)
        player.effects = remaining;

    const { maxHealth } = getPlayerStats(player);
    if (player.health > maxHealth) {
        player.health = maxHealth;
        changed = true;
    }

    return changed;
}

/** Natural HP regeneration for players out of combat. Periodic cadence only. Returns whether healed. */
export function processRegenTick(player: PlayerState): boolean {
    // Via getActiveEffects (not raw `player.effects`) so an already-elapsed disengage countdown
    // cannot wedge regen off. Held combat carries no `expiresAt` and so still pauses regen
    // indefinitely — the battleground exploit stays closed. `player.dead` must be tested first:
    // getActiveEffects returns [] for a corpse, which would otherwise invert this branch.
    if (player.dead || getActiveEffects(player).some(e => e.id === 'combat'))
        return false;

    // Deliberately the POSITIVE form: `regen > 0 && health < maxHealth` bails on a NaN, whereas
    // the inverted `regen <= 0 || health >= maxHealth` would fall through and persist NaN health.
    const stats = getPlayerStats(player);
    if (!(stats.regen > 0 && player.health < stats.maxHealth))
        return false;

    // Record what was ACTUALLY restored, not the full rate — a player within `regen` of their
    // maximum heals less than the rate, and the statistic must reflect that.
    const healed = restoreHealth(player, stats.regen);
    if (!(healed > 0))
        return false;

    void statisticsRepository.increment('total_hp_regen', healed);

    return true;
}
