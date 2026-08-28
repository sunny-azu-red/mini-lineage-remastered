import type { BattleNarrative } from '@shared/contract';
import type { PlayerState, BattleResult, Race } from '@/interface';
import { WEAPONS, ARMORS, RACES } from '@/constant/game.constant';
import {
    BATTLE_DEFLECTION_TEMPLATES,
    BATTLE_KILL_TEMPLATES,
    BATTLE_MOVES,
    BATTLE_OUTCOME_TEMPLATES,
    BATTLE_AMBUSH_TEMPLATES,
    BATTLE_CRITICAL_TEMPLATES,
    BATTLE_LEVEL_UP_TEMPLATES,
    RACE_TRAITS_TEMPLATES,
} from '@/constant/narratives.constant';
import { fillTemplate, formatAdena, formatNumber, pluralize } from '@/util/format.util';
import { randomElement } from '@/util/game.util';
import { getAmbushEnemyCount } from '@/service/math.service';

/**
 * Builds the full battle narrative for a resolved fight — ported faithfully from
 * the deleted battle.view.ts's renderBattlegroundView, minus the EJS render step.
 *
 * `ambushedAfter` is the NEW ambush state (what player.ambushed becomes once this
 * fight resolves and a fresh ambush chance has been rolled) — it is passed in by
 * the caller rather than decided here, keeping this function pure/side-effect-free.
 */
export function buildBattleNarrative(player: PlayerState, result: BattleResult, ambushedAfter: boolean): BattleNarrative {
    const weapon = WEAPONS[player.weaponId];
    const armor = ARMORS[player.armorId];
    const enemies = result.enemiesKilled;

    // determine opponent based on the race's configured enemy
    const race = RACES[player.raceId];
    const opponentRace = RACES[race.enemyRaceId];
    const enemyEmoji = opponentRace.emoji;
    const enemyName = opponentRace.label;
    const enemyGroup = pluralize(opponentRace.label, opponentRace.plural, enemies, enemyEmoji);

    const templateData = {
        weaponEmoji: weapon.emoji,
        weaponName: weapon.name,
        armorEmoji: armor.emoji,
        armorName: armor.name,
        enemyGroup,
        enemyEmoji,
        enemyName,
        blocked: formatNumber(result.damageBlocked),
        xpGained: formatNumber(result.xpGained),
        adenaGained: formatAdena(result.adenaGained),
        hp: formatNumber(player.health),
        isSingleEnemy: enemies === 1,
    };

    const critLine = result.isCritical ? fillTemplate(randomElement(BATTLE_CRITICAL_TEMPLATES), templateData) : null;
    const killLine = fillTemplate(randomElement(BATTLE_KILL_TEMPLATES), templateData);
    const deflectionLine = fillTemplate(randomElement(BATTLE_DEFLECTION_TEMPLATES), templateData);
    const outcomeLine = fillTemplate(randomElement(result.isLevelUp ? BATTLE_LEVEL_UP_TEMPLATES : BATTLE_OUTCOME_TEMPLATES), templateData);

    // ambush
    const ambushEnemies = getAmbushEnemyCount(enemies, 4);
    const ambushEnemyGroup = pluralize(opponentRace.label, opponentRace.plural, ambushEnemies, enemyEmoji);
    const ambushData = {
        ...templateData,
        ambushEnemyGroup,
        ambushEnemyGroupCap: ambushEnemyGroup.charAt(0).toUpperCase() + ambushEnemyGroup.slice(1),
        isSingleAmbush: ambushEnemies === 1,
    };
    const ambushText = fillTemplate(randomElement(BATTLE_AMBUSH_TEMPLATES), ambushData);

    return {
        critLine,
        killLine,
        deflectionLine,
        outcomeLine,
        ambushLine: ambushedAfter ? ambushText : null,
        fightPrompt: ambushedAfter ? (ambushEnemies === 1 ? 'Face your Foe!' : 'Fight them!') : null,
        nextMove: randomElement(BATTLE_MOVES),
    };
}

/**
 * Fills the race-traits template for a given race — the single source both
 * race.view.ts and player.view.ts's renderCharacterView duplicated identically.
 */
export function buildRaceTraits(race: Race): string {
    return fillTemplate(RACE_TRAITS_TEMPLATES[race.id], {
        hp: formatNumber(race.startHealth),
        adena: formatAdena(race.startAdena),
        crit: formatNumber(race.crit),
        regen: formatNumber(race.regen),
        ambush: formatNumber(race.ambushChance),
    });
}
