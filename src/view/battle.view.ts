import { readTemplate, render } from './base.view';
import { renderPage } from './layout.view';
import { PlayerState, BattleResult, FlashMessage } from '@/interface';
import { WEAPONS, ARMORS, RACES } from '@/constant/game.constant';
import { BATTLE_DEFLECTION_TEMPLATES, BATTLE_KILL_TEMPLATES, BATTLE_MOVES, BATTLE_OUTCOME_TEMPLATES, BATTLE_AMBUSH_TEMPLATES, BATTLE_CRITICAL_TEMPLATES, BATTLE_LEVEL_UP_TEMPLATES } from '@/constant/narratives.constant';
import { fillTemplate, formatAdena, formatNumber, pluralize } from '@/util/format.util';
import { randomElement } from '@/util/game.util';
import { getAmbushEnemyCount } from '@/service/math.service';

const battlegroundTpl = readTemplate('battleground.ejs');

export function renderBattlegroundView(player: PlayerState, results: BattleResult, flash: FlashMessage | null = null): string {
    const weapon = WEAPONS[player.weaponId];
    const armor = ARMORS[player.armorId];
    const enemies = results.enemiesKilled;

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
        blocked: formatNumber(results.damageBlocked),
        xpGained: formatNumber(results.xpGained),
        adenaGained: formatAdena(results.adenaGained),
        hp: formatNumber(player.health),
        isSingleEnemy: enemies === 1,
    };

    const critText = results.isCritical ? fillTemplate(randomElement(BATTLE_CRITICAL_TEMPLATES), templateData) : '';
    const killText = fillTemplate(randomElement(BATTLE_KILL_TEMPLATES), templateData);
    const deflectionText = fillTemplate(randomElement(BATTLE_DEFLECTION_TEMPLATES), templateData);
    const outcomeText = fillTemplate(randomElement(results.isLevelUp ? BATTLE_LEVEL_UP_TEMPLATES : BATTLE_OUTCOME_TEMPLATES), templateData);

    // ambush
    const ambushEnemies = getAmbushEnemyCount(enemies, 4);
    const ambushEnemyGroup = pluralize(opponentRace.label, opponentRace.plural, ambushEnemies, enemyEmoji);
    const ambushData = {
        ...templateData,
        ambushEnemyGroup,
        ambushEnemyGroupCap: ambushEnemyGroup.charAt(0).toUpperCase() + ambushEnemyGroup.slice(1),
        isSingleAmbush: ambushEnemies === 1
    };
    const ambushText = fillTemplate(randomElement(BATTLE_AMBUSH_TEMPLATES), ambushData);

    const content = render(battlegroundTpl, {
        critLine: critText,
        killLine: killText,
        deflectionLine: deflectionText,
        outcomeLine: outcomeText,
        ambushed: player.ambushed,
        ambushedLine: ambushText,
        fightText: ambushEnemies === 1 ? `Face your Foe!` : `Fight them!`,
        nextMove: randomElement(BATTLE_MOVES),
        sound: flash?.sound ? undefined : (player.ambushed ? 'ambush' : (results.isCritical ? 'crit' : undefined)),
    });

    return renderPage('Battleground', player, content, flash);
}
