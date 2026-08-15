import { readTemplate, render } from './base.view';
import { renderPage, renderSimplePage } from './layout.view';
import { PlayerState, FlashMessage } from '@/interface';
import { calculateLevel, getXpNeededToLevelUp, isMaxLevel } from '@/service/math.service';
import { getTotalAttack, getTotalDefense, getTotalCrit, getTotalRegen } from '@/service/player.service';
import { RACES, WEAPONS, ARMORS } from '@/constant/game.constant';
import { RACE_TRAITS_TEMPLATES, DEATH_MESSAGES } from '@/constant/narratives.constant';
import { formatNumber, formatAdena, fillTemplate, pluralize } from '@/util/format.util';
import { randomElement } from '@/util/game.util';

const suicideTpl = readTemplate('suicide.ejs');
const deathTpl = readTemplate('death.ejs');
const characterTpl = readTemplate('character.ejs');

export function renderSuicideView(player: PlayerState, flash: FlashMessage | null = null): string {
    return renderPage('Commit Suicide', player, render(suicideTpl), flash, {
        hideLowHealthAlert: true
    });
}

export function renderDeathView(player: PlayerState): string {
    if (!player.deathReason) {
        if (player.coward) {
            player.deathReason = player.ambushed
                ? "🪤 You were caught trying to flee an ambush!"
                : "🤡 You took the cowardly way out.";
        } else {
            player.deathReason = randomElement(DEATH_MESSAGES);
        }
    }

    const content = render(deathTpl, {
        reason: player.deathReason,
        coward: player.coward
    });

    return renderPage('Game Over', player, content);
}

export function renderCharacterView(player: PlayerState, flash: FlashMessage | null = null): string {
    const race = RACES[player.raceId];
    const opponentRace = RACES[race.enemyRaceId];
    const weapon = WEAPONS[player.weaponId];
    const armor = ARMORS[player.armorId];

    const currentLevel = calculateLevel(player.experience);
    const xpNeeded = getXpNeededToLevelUp(player.experience);

    const raceTraits = fillTemplate(RACE_TRAITS_TEMPLATES[race.id], {
        hp: formatNumber(race.startHealth),
        adena: formatAdena(race.startAdena),
        crit: formatNumber(race.crit),
        regen: formatNumber(race.regen),
        ambush: formatNumber(race.ambushChance),
    });

    const enemiesKilled = player.totalEnemiesKilled ?? 0;
    const opponentRaceGroup = pluralize(opponentRace.label, opponentRace.plural, enemiesKilled, opponentRace.emoji);
    const battlesGroup = pluralize('battle', 'battles', player.totalBattles ?? 0);
    const ambushesGroup = pluralize('cunning ambush', 'cunning ambushes', player.totalAmbushes ?? 0);

    const content = render(characterTpl, {
        playerName: player.name,
        raceLabel: race.label,
        raceEmoji: race.emoji,
        raceBackstory: race.backstory,
        raceTraits,
        weaponName: weapon.name,
        weaponEmoji: weapon.emoji,
        weaponCrit: weapon.crit ?? 0,
        armorName: armor.name,
        armorEmoji: armor.emoji,
        armorRegen: armor.regen ?? 0,
        attackPower: formatNumber(getTotalAttack(player)),
        defensePower: formatNumber(getTotalDefense(player)),
        totalCrit: formatNumber(getTotalCrit(player)),
        totalRegen: formatNumber(getTotalRegen(player)),
        ambushChance: formatNumber(race.ambushChance),
        battlesGroup,
        opponentRaceGroup,
        ambushesGroup,
        hp: player.health,
        hpFormatted: formatNumber(player.health),
        maxHpFormatted: formatNumber(race.startHealth),
        adenaFormatted: formatAdena(player.adena),
        level: formatNumber(currentLevel),
        nextLevel: formatNumber(currentLevel + 1),
        totalXpFormatted: formatNumber(player.experience),
        xpNeededFormatted: formatNumber(xpNeeded),
        isMaxLevel: isMaxLevel(currentLevel),
    });

    return renderSimplePage('Character', content, flash, player);
}
