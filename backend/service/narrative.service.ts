import type { BattleNarrative } from '@shared/contract';
import type { PlayerState, BattleResult, Race } from '@/interface';
import { WEAPONS, ARMORS, RACES } from '@/constant/game.constant';
import {
    BATTLE_DEFLECTION_TEMPLATES, BATTLE_KILL_TEMPLATES, BATTLE_MOVES, BATTLE_OUTCOME_TEMPLATES,
    BATTLE_AMBUSH_TEMPLATES, BATTLE_CRITICAL_TEMPLATES, BATTLE_LEVEL_UP_TEMPLATES, RACE_TRAITS_TEMPLATES,
} from '@/constant/narratives.constant';
import { fillTemplate, formatAdena, formatNumber, pluralize, capitalize } from '@/util/format.util';
import { randomElement } from '@/util/game.util';
import { getAmbushEnemyCount } from '@/service/math.service';

const pick = (templates: string[], data: Record<string, unknown>) => fillTemplate(randomElement(templates), data);

/**
 * Builds the narrative for a resolved fight. `ambushedAfter` is the NEW ambush state, passed in
 * by the caller rather than rolled here, keeping this function side-effect-free.
 */
export function buildBattleNarrative(player: PlayerState, result: BattleResult, ambushedAfter: boolean): BattleNarrative {
    const weapon = WEAPONS[player.weaponId];
    const armor = ARMORS[player.armorId];
    const enemy = RACES[RACES[player.raceId].enemyRaceId];
    const enemies = result.enemiesKilled;

    const ambushEnemies = getAmbushEnemyCount(enemies, 4);
    const ambushEnemyGroup = pluralize(enemy.label, enemy.plural, ambushEnemies, enemy.emoji);

    const data = {
        weaponEmoji: weapon.emoji,
        weaponName: weapon.name,
        armorEmoji: armor.emoji,
        armorName: armor.name,
        enemyGroup: pluralize(enemy.label, enemy.plural, enemies, enemy.emoji),
        enemyEmoji: enemy.emoji,
        enemyName: enemy.label,
        blocked: formatNumber(result.damageBlocked),
        xpGained: formatNumber(result.xpGained),
        adenaGained: formatAdena(result.adenaGained),
        hp: formatNumber(player.health),
        isSingleEnemy: enemies === 1,
        ambushEnemyGroup,
        ambushEnemyGroupCap: capitalize(ambushEnemyGroup),
        isSingleAmbush: ambushEnemies === 1,
    };

    // Drawn as statements, in this exact order, because each one consumes a Math.random() —
    // reordering them (or making the ambush draw conditional) would shift every later roll in
    // the request. The ambush template is always SELECTED; only its fill is skipped when unused.
    const critLine = result.isCritical ? pick(BATTLE_CRITICAL_TEMPLATES, data) : null;
    const killLine = pick(BATTLE_KILL_TEMPLATES, data);
    const deflectionLine = pick(BATTLE_DEFLECTION_TEMPLATES, data);
    const outcomeLine = pick(result.isLevelUp ? BATTLE_LEVEL_UP_TEMPLATES : BATTLE_OUTCOME_TEMPLATES, data);
    const ambushTemplate = randomElement(BATTLE_AMBUSH_TEMPLATES);

    return {
        critLine,
        killLine,
        deflectionLine,
        outcomeLine,
        ambushLine: ambushedAfter ? fillTemplate(ambushTemplate, data) : null,
        fightPrompt: ambushedAfter ? (ambushEnemies === 1 ? 'Face your Foe!' : 'Fight them!') : null,
        nextMove: randomElement(BATTLE_MOVES),
    };
}

export function buildRaceTraits(race: Race): string {
    return fillTemplate(RACE_TRAITS_TEMPLATES[race.id], {
        hp: formatNumber(race.startHealth),
        adena: formatAdena(race.startAdena),
        crit: formatNumber(race.crit),
        regen: formatNumber(race.regen),
        ambush: formatNumber(race.ambushChance),
    });
}
