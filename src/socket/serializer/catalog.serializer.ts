import type { GameCatalog, RaceView } from '@shared/contract';
import { RACES, WEAPONS, ARMORS, FOODS, GAME_VERSION, LOCALE, HP_CONFIG, MAX_LEVEL, CHARACTER_CONFIG } from '@/constant/game.constant';
import { isRelease } from '@/util/version.util';
import { slugify } from '@/util/format.util';
import { buildRaceTraits } from '@/service/narrative.service';
import { toItemView } from './player.serializer';

let cachedCatalog: GameCatalog | null = null;

/**
 * Builds the static game catalog (races/weapons/armors/foods + version/locale
 * config) sent once as part of every hydrate payload. None of its inputs ever
 * change at runtime, so the result is computed once and memoized.
 */
export function buildGameCatalog(): GameCatalog {
    if (cachedCatalog)
        return cachedCatalog;

    const races: RaceView[] = RACES.map(race => ({
        id: race.id,
        label: race.label,
        plural: race.plural,
        emoji: race.emoji,
        slug: slugify(race.label),
        enemyRaceId: race.enemyRaceId,
        startHealth: race.startHealth,
        startAdena: race.startAdena,
        ambushChance: race.ambushChance,
        regen: race.regen,
        crit: race.crit,
        backstory: race.backstory,
        traits: buildRaceTraits(race),
    }));

    cachedCatalog = {
        version: GAME_VERSION,
        isRelease: isRelease(GAME_VERSION),
        year: new Date().getFullYear(),
        locale: LOCALE,
        lowHealthThreshold: HP_CONFIG.lowHealthThreshold,
        maxLevel: MAX_LEVEL,
        nameMinLength: CHARACTER_CONFIG.nameMinLength,
        nameMaxLength: CHARACTER_CONFIG.nameMaxLength,
        races,
        weapons: WEAPONS.map(toItemView),
        armors: ARMORS.map(toItemView),
        foods: FOODS.map(toItemView),
    };

    return cachedCatalog;
}
