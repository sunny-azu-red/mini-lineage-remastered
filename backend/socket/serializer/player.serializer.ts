import type { PlayerSnapshot, ItemView } from '@shared/contract';
import type { PlayerState, Item } from '@/interface';
import { calculateLevel, getXpProgress, getXpNeededToLevelUp, isMaxLevel, calculatePercentage, isLowHealth } from '@/service/math.service';
import { getPlayerStats, getActiveEffects, isGameStarted } from '@/service/player.service';
import { formatEffectTooltip } from '@/util/format.util';
import { getItemModifier } from '@/util/game.util';
import { RACES, WEAPONS, ARMORS } from '@/constant/game.constant';

/**
 * Flattens an Item's modifiers into a display-ready ItemView. Shared by
 * the player snapshot serializer and the (static) game catalog serializer.
 */
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

const EMPTY_SNAPSHOT_DEFAULTS: Omit<PlayerSnapshot, 'revision'> = {
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

/**
 * Replaces layout.view.ts's renderStatus/renderInventory/renderEffects and
 * player.view.ts's renderCharacterView data-assembly with a single pure
 * PlayerState -> PlayerSnapshot mapping. Reuses every existing math/player
 * service computation rather than re-deriving it.
 */
export function buildPlayerSnapshot(player: PlayerState): PlayerSnapshot {
    const revision = player.revision ?? 0;

    if (!isGameStarted(player))
        return { revision, ...EMPTY_SNAPSHOT_DEFAULTS };

    const race = RACES[player.raceId];
    const weapon = WEAPONS[player.weaponId];
    const armor = ARMORS[player.armorId];
    const stats = getPlayerStats(player);
    const activeEffects = getActiveEffects(player);

    const level = calculateLevel(player.experience);
    const xpProgress = getXpProgress(player.experience);
    const xpNeeded = getXpNeededToLevelUp(player.experience);

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
        xpCurrent: xpProgress.current,
        xpRequired: xpProgress.required,
        xpPercent: xpProgress.percent,
        xpNeeded,

        adena: player.adena,

        weapon: toItemView(weapon),
        armor: toItemView(armor),

        stats: {
            attack: stats.attack,
            defense: stats.defense,
            crit: stats.crit,
            regen: stats.regen,
            ambushRisk: stats.ambushRisk,
        },
        effects: activeEffects.map(effect => ({
            id: effect.id,
            type: effect.type,
            emoji: effect.emoji,
            label: effect.label,
            tooltip: formatEffectTooltip(effect),
            expiresAt: effect.expiresAt,
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
