import type { RaceView } from '@shared/contract';
import type { ScreenId } from '@shared/contract';

/**
 * The single source of truth for the handful of link-worthy URLs, used in BOTH directions —
 * previously two hand-maintained inverse functions that could silently drift apart.
 * 'start'/'home' share '/' and are disambiguated by `started`; 'error' has no URL.
 *
 * Lives outside `useHistorySync` so the store can resolve the boot screen from the URL on the
 * first hydrate, without either side owning a second copy of the table. Access rules are NOT
 * enforced here — `pinScreen` (gameStore.ts) owns every one of them, and both callers reach it.
 */
const ROUTES = [
    ['battle', '/battle'],
    ['weapons', '/shop/weapons'],
    ['armors', '/shop/armors'],
    ['inn', '/inn'],
    ['suicide', '/suicide'],
    ['death', '/death'],
    ['character', '/character'],
    ['highscores', '/highscores'],
    ['statistics', '/statistics'],
    ['races', '/races'],
] as const satisfies readonly (readonly [ScreenId, string])[];

const HIGHSCORES_PREFIX = '/highscores/';

export function pathFor(screen: ScreenId, raceFilter: number | null, races: RaceView[]): string | null {
    if (screen === 'start' || screen === 'home')
        return '/';
    if (screen === 'highscores' && raceFilter !== null) {
        const race = races.find(r => r.id === raceFilter);
        return race ? `${HIGHSCORES_PREFIX}${race.slug}` : '/highscores';
    }

    // 'error' has no link-worthy URL and nothing to deep-link back into — leave the bar alone.
    return ROUTES.find(([id]) => id === screen)?.[1] ?? null;
}

/** Resolves a URL to the screen it names. */
export function screenFromPath(pathname: string): ScreenId {
    if (pathname.startsWith(HIGHSCORES_PREFIX))
        return 'highscores';

    // Unknown paths resolve to Home; pinScreen demotes that to Game Start for a visitor with no
    // character, so this needs no knowledge of player state.
    return ROUTES.find(([, path]) => path === pathname)?.[0] ?? 'home';
}

export function raceFilterFromPath(pathname: string, races: RaceView[]): number | null {
    if (!pathname.startsWith(HIGHSCORES_PREFIX))
        return null;

    return races.find(r => r.slug === pathname.slice(HIGHSCORES_PREFIX.length))?.id ?? null;
}
