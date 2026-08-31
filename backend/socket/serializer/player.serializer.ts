import type { PlayerSnapshot, ItemView } from '@shared/contract';
import type { PlayerState, Item } from '@/interface';
import { calculateLevel, getXpProgress, getXpNeededToLevelUp, isMaxLevel, calculatePercentage, isLowHealth } from '@/service/math.service';
import { getPlayerStats, getActiveEffects, isGameStarted } from '@/service/player.service';
import { formatEffectTooltip } from '@/util/format.util';
import { getItemModifier } from '@/util/game.util';
import { RACES, WEAPONS, ARMORS } from '@/constant/game.constant';

/** Flattens an Item's modifiers into a display-ready view. */
export function toItemView(item: Item): ItemView {
    return {
        id: item.id,
        name: item.name,
        emoji: item.emoji,
        stat: item.stat,
        cost: item.cost,
        crit: getItemModifier(item, 'crit'),
        regen: getItemModifier(item, 'regen'),
        maxHealth: getItemModifier(item, 'maxHealth'),
    };
}

const EMPTY_SNAPSHOT: Omit<PlayerSnapshot, 'revision'> = {
    started: false,
    name: null,
    raceId: null,
    raceLabel: null,
    raceEmoji: null,
    health: null,
    maxHealth: null,
    hpPercent: 0,
    lowHealth: false,
    experience: null,
    level: null,
    isMaxLevel: false,
    xpCurrent: 0,
    xpRequired: 0,
    xpPercent: 0,
    xpNeeded: 0,
    adena: null,
    weapon: null,
    armor: null,
    stats: null,
    effects: [],
    dead: false,
    ambushed: false,
    coward: false,
    cheated: false,
    deathReason: null,
    highscoreEligible: false,
    counters: { totalBattles: 0, totalAmbushes: 0, consecutiveAmbushes: 0, totalEnemiesKilled: 0 },
    lastBattle: null,
};

/** The single pure PlayerState -> PlayerSnapshot mapping. Reuses the math/player services. */
export function buildPlayerSnapshot(player: PlayerState): PlayerSnapshot {
    const revision = player.revision ?? 0;

    if (!isGameStarted(player))
        return { revision, ...EMPTY_SNAPSHOT };

    const race = RACES[player.raceId];
    const stats = getPlayerStats(player);
    const level = calculateLevel(player.experience);
    const xp = getXpProgress(player.experience);

    return {
        revision,
        started: true,

        name: player.name,
        raceId: player.raceId,
        raceLabel: race?.label ?? null,
        raceEmoji: race?.emoji ?? null,

        health: player.health,
        maxHealth: stats.maxHealth,
        hpPercent: calculatePercentage(player.health, stats.maxHealth),
        lowHealth: isLowHealth(player.health, stats.maxHealth),

        experience: player.experience,
        level,
        isMaxLevel: isMaxLevel(level),
        xpCurrent: xp.current,
        xpRequired: xp.required,
        xpPercent: xp.percent,
        xpNeeded: getXpNeededToLevelUp(player.experience),

        adena: player.adena,

        weapon: toItemView(WEAPONS[player.weaponId]),
        armor: toItemView(ARMORS[player.armorId]),

        stats: {
            attack: stats.attack,
            defense: stats.defense,
            crit: stats.crit,
            regen: stats.regen,
            ambushRisk: stats.ambushRisk,
        },
        effects: getActiveEffects(player).map(effect => ({
            id: effect.id,
            type: effect.type,
            emoji: effect.emoji,
            label: effect.label,
            tooltip: formatEffectTooltip(effect),
            // Converted to a duration here, at the one place state crosses to the client, so the
            // two machines' clocks never need reconciling. Stored state stays absolute.
            remainingMs: effect.expiresAt === undefined ? undefined : Math.max(0, effect.expiresAt - Date.now()),
        })),

        dead: Boolean(player.dead),
        ambushed: Boolean(player.ambushed),
        coward: Boolean(player.coward),
        cheated: Boolean(player.cheated),
        deathReason: player.deathReason ?? null,
        highscoreEligible: player.dead === true && !player.coward && !player.cheated,

        counters: {
            totalBattles: player.totalBattles ?? 0,
            totalAmbushes: player.totalAmbushes ?? 0,
            consecutiveAmbushes: player.consecutiveAmbushes ?? 0,
            totalEnemiesKilled: player.totalEnemiesKilled ?? 0,
        },

        lastBattle: player.lastBattleNarrative ?? null,
    };
}
