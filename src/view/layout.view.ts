import { readTemplate, render } from './base.view';
import { WEAPONS, ARMORS, RACES, GAME_VERSION, REPO_COMMIT_URL } from '@/constant/game.constant';
import { calculateLevel, isLowHealth, calculatePercentage, getXpProgress, isMaxLevel } from '@/service/math.service';
import { isGameStarted, getPlayerStats, getActiveEffects } from '@/service/player.service';
import { formatAdena, formatNumber, formatEffectTooltip, formatEffectTimer } from '@/util/format.util';
import { randomElement, getItemModifier } from '@/util/game.util';
import { isRelease } from '@/util/version.util';
import { AMBUSH_LOW_HEALTH_MESSAGES } from '@/constant/narratives.constant';
import { PlayerState, RenderOptions, FlashMessage } from '@/interface';

const layoutTpl = readTemplate('layout.ejs');
const simpleTpl = readTemplate('simple.ejs');
const statusTpl = readTemplate('partials/status.ejs');
const inventoryTpl = readTemplate('partials/inventory.ejs');


function getVersionHtml(): string {
    return isRelease(GAME_VERSION)
        ? `<a href="${REPO_COMMIT_URL}${GAME_VERSION}" target="_blank" class="version-link">${GAME_VERSION}</a>`
        : `<span class="version-debug">${GAME_VERSION}</span>`;
}

export function renderStatus(player: PlayerState): string {
    const level = calculateLevel(player.experience);
    const hp = player.health;
    const { current: currentXp, required: nextLevelXp, percent: xpPercent } = getXpProgress(player.experience);

    const race = RACES[player.raceId];
    const stats = getPlayerStats(player);
    const maxHp = stats.maxHealth;

    const statusEmoji = player.dead ? '☠️' : race.emoji;
    const levelDisplay = (player.ambushed || player.dead)
        ? `${statusEmoji} <span class="gold">${race.label} level ${formatNumber(level)}</span>`
        : `${statusEmoji} <a href='/character'>${race.label} level ${formatNumber(level)}</a>`;

    return render(statusTpl, {
        hp,
        maxHp,
        hpFormatted: formatNumber(hp),
        maxHpFormatted: formatNumber(maxHp),
        hpPercent: calculatePercentage(hp, maxHp),
        xpPercent,
        currentXpFormatted: formatNumber(currentXp),
        nextLevelXpFormatted: formatNumber(nextLevelXp),
        totalXpFormatted: formatNumber(player.experience),
        currentXp,
        totalXp: player.experience,
        isMaxLevel: isMaxLevel(level),
        isLowHealth: isLowHealth(hp, maxHp),
        adena: player.adena,
        adenaFormatted: formatAdena(player.adena),
        level,
        levelDisplay,
        playerName: player.name,
    });
}

export function renderInventory(player: PlayerState): string {
    const weapon = WEAPONS[player.weaponId];
    const armor = ARMORS[player.armorId];

    return render(inventoryTpl, {
        armorEmoji: armor.emoji,
        armorName: armor.name,
        armorStat: getItemModifier(armor, 'regen'),
        weaponEmoji: weapon.emoji,
        weaponName: weapon.name,
        weaponStat: getItemModifier(weapon, 'crit'),
    });
}

export function renderEffects(player: PlayerState): string {
    const effects = getActiveEffects(player);
    const now = Date.now();
    return effects.map(effect => {
        const typeClass = effect.type ? ` effect-${effect.type}` : '';
        let timerHtml = '';
        let expiresAttr = '';
        if (effect.expiresAt) {
            const remSec = Math.max(0, Math.ceil((effect.expiresAt - now) / 1000));
            expiresAttr = ` data-expires-at="${effect.expiresAt}"`;
            timerHtml = `<span class="effect-timer">${formatEffectTimer(remSec)}</span>`;
        }
        const tooltip = formatEffectTooltip(effect);
        return `<span class="effect-icon effect-fade-in${typeClass}" data-effect-id="${effect.id}" data-label="${effect.label}"${expiresAttr} title="${tooltip}"><span class="effect-emoji">${effect.emoji}</span>${timerHtml}</span>`;
    }).join('');
}

export function renderPage(title: string, player: PlayerState, mainContent: string, flash: FlashMessage | null = null, options: RenderOptions = {}): string {
    const statusHtml = renderStatus(player);
    const inventoryHtml = renderInventory(player);
    const effectsHtml = renderEffects(player);

    const stats = getPlayerStats(player);
    const maxHp = stats.maxHealth;

    let lowHealthAlert = '';
    if (!player.dead && isLowHealth(player.health, maxHp) && !options.hideLowHealthAlert) {
        lowHealthAlert = player.ambushed
            ? `Your HP is dangerously low!<br>${randomElement(AMBUSH_LOW_HEALTH_MESSAGES)}`
            : `Your HP is dangerously low!<br>You should buy some food from the 🍺 <a href='/inn'>Inn</a> to regain your strength.`;
    }

    return render(layoutTpl, {
        title,
        mainContent,
        statusHtml,
        inventoryHtml,
        effectsHtml,
        lowHealthAlert,
        flash,
        headerClickable: !player.ambushed && !player.dead,
        year: new Date().getFullYear(),
        version: getVersionHtml(),
        isRelease: isRelease(GAME_VERSION),
    });
}

export function renderSimplePage(title: string, mainContent: string, flash: FlashMessage | null = null, player: PlayerState | null = null): string {
    const effectsHtml = (player && isGameStarted(player)) ? renderEffects(player) : '';
    return render(simpleTpl, {
        title,
        mainContent,
        flash,
        effectsHtml,
        headerClickable: (player && isGameStarted(player)) ? (!player.ambushed && !player.dead) : true,
        year: new Date().getFullYear(),
        version: getVersionHtml(),
        isRelease: isRelease(GAME_VERSION),
    });
}
