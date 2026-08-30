import type { GameCatalog, RaceView } from '@shared/contract';
import type { Race } from '@/interface';
import { RACES, WEAPONS, ARMORS, FOODS, GAME_VERSION, REPO_COMMIT_URL, LOCALE, HP_CONFIG, MAX_LEVEL, CHARACTER_CONFIG } from '@/constant/game.constant';
import { isRelease } from '@/util/version.util';
import { slugify } from '@/util/format.util';
import { buildRaceTraits } from '@/service/narrative.service';
import { toItemView } from './player.serializer';

/**
 * `races` below spreads the whole `Race` record into the client payload, so every Race field is
 * public by construction. This makes that a COMPILE error rather than a silent leak: adding a
 * field to `Race` that isn't on `RaceView` flips this type to `false` and fails the build.
 */
const _everyRaceFieldIsPublic: Exclude<keyof Race, keyof RaceView> extends never ? true : false = true;
void _everyRaceFieldIsPublic;

let cachedCatalog: GameCatalog | null = null;

/** The static catalog sent with every hydrate. No input ever changes at runtime, so memoize it. */
export function buildGameCatalog(): GameCatalog {
    if (cachedCatalog)
        return cachedCatalog;

    const release = isRelease(GAME_VERSION);

    return cachedCatalog = {
        version: GAME_VERSION,
        isRelease: release,
        // Straight concatenation — REPO_COMMIT_URL already ends with a slash.
        commitUrl: release ? `${REPO_COMMIT_URL}${GAME_VERSION}` : null,
        year: new Date().getFullYear(),
        locale: LOCALE,
        lowHealthThreshold: HP_CONFIG.lowHealthThreshold,
        maxLevel: MAX_LEVEL,
        nameMinLength: CHARACTER_CONFIG.nameMinLength,
        nameMaxLength: CHARACTER_CONFIG.nameMaxLength,
        races: RACES.map(race => ({ ...race, slug: slugify(race.label), traits: buildRaceTraits(race) })),
        weapons: WEAPONS.map(toItemView),
        armors: ARMORS.map(toItemView),
        foods: FOODS.map(toItemView),
    };
}
