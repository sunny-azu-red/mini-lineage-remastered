import { useEffect, useRef } from 'react';
import type { RaceView } from '@shared/contract';
import { useGameStore, type ScreenId } from '@/store/gameStore';

/**
 * DECISION — why every path here is prefixed `/app`, not bare `/` as plan decision A4 originally
 * sketched (`home -> '/'`, `battle -> '/battle'`, ...): `src/route/game.route.ts` (the still-live
 * legacy EJS app, untouched during this additive/parallel-run phase) already owns EVERY one of
 * those exact paths (`/`, `/battle`, `/shop/weapons`, `/highscores/:raceLabel`, ...), and
 * `src/route/error.route.ts` mounts a catch-all 404 `router.use()` right after it. There is no
 * "unclaimed" path left at the root for a new SPA-fallback route to own without shadowing the
 * legacy app. Per the plan's own fallback contingency, the new client instead lives under a
 * dedicated `/app` prefix for the duration of this transition (see `src/app.ts`'s matching
 * `/app`, `/app/*splat` route) — once the legacy router is demolished (a later task), both this
 * map and that route can drop the prefix and own `/` outright.
 */
const APP_PREFIX = '/app';

function pathFor(screen: ScreenId, raceFilter: number | null, races: RaceView[]): string | null {
    switch (screen) {
        case 'start':
        case 'home':
            return `${APP_PREFIX}/`;
        case 'battle':
            return `${APP_PREFIX}/battle`;
        case 'weapons':
            return `${APP_PREFIX}/shop/weapons`;
        case 'armors':
            return `${APP_PREFIX}/shop/armors`;
        case 'inn':
            return `${APP_PREFIX}/inn`;
        case 'suicide':
            return `${APP_PREFIX}/suicide`;
        case 'death':
            return `${APP_PREFIX}/death`;
        case 'character':
            return `${APP_PREFIX}/character`;
        case 'highscores': {
            if (raceFilter === null)
                return `${APP_PREFIX}/highscores`;

            const race = races.find(r => r.id === raceFilter);
            return race ? `${APP_PREFIX}/highscores/${race.slug}` : `${APP_PREFIX}/highscores`;
        }
        case 'statistics':
            return `${APP_PREFIX}/statistics`;
        case 'races':
            return `${APP_PREFIX}/races`;
        case 'error':
            // No genuinely link-worthy URL for an error state, and nothing to deep-link back
            // into — leave the address bar exactly as it was (plan's "your call, minor").
            return null;
        default:
            return null;
    }
}

/** Reverse of `pathFor` — used both for `popstate` events with no `state` payload (Safari/older
 * browsers can fire one) and for reconciling a hard page-load landing directly on a deep link. */
function screenFromPath(pathname: string, started: boolean): ScreenId {
    const path = pathname.startsWith(APP_PREFIX) ? pathname.slice(APP_PREFIX.length) || '/' : pathname;

    if (path === '/' || path === '')
        return started ? 'home' : 'start';
    if (path === '/battle')
        return 'battle';
    if (path === '/shop/weapons')
        return 'weapons';
    if (path === '/shop/armors')
        return 'armors';
    if (path === '/inn')
        return 'inn';
    if (path === '/suicide')
        return 'suicide';
    if (path === '/death')
        return 'death';
    if (path === '/character')
        return 'character';
    if (path === '/highscores' || path.startsWith('/highscores/'))
        return 'highscores';
    if (path === '/statistics')
        return 'statistics';
    if (path === '/races')
        return 'races';

    return started ? 'home' : 'start';
}

function raceFilterFromPath(pathname: string, races: RaceView[]): number | null {
    const path = pathname.startsWith(APP_PREFIX) ? pathname.slice(APP_PREFIX.length) : pathname;
    const prefix = '/highscores/';

    if (!path.startsWith(prefix))
        return null;

    const slug = path.slice(prefix.length);
    return races.find(r => r.slug === slug)?.id ?? null;
}

interface HistoryState {
    screen: ScreenId;
    raceFilter: number | null;
}

function isHistoryState(value: unknown): value is HistoryState {
    return typeof value === 'object' && value !== null && 'screen' in value;
}

/**
 * Maps `store.screen`/`store.highscoreRaceFilter` <-> browser history (plan decision A4) for the
 * handful of genuinely link-worthy URLs, giving Back/Forward support with no router dependency.
 * Call once from App.tsx.
 *
 * Loop safety: a `screen` change triggers a `pushState` (one effect below); a `popstate` event
 * triggers a `store.navigate()` call (the other effect) which itself changes `screen` — without a
 * guard that would immediately re-trigger the first effect and `pushState` AGAIN on top of the
 * entry `popstate` just navigated to. `fromPopStateRef` breaks this: whenever a navigation
 * originates from `popstate` (or the one-time initial-deep-link reconciliation below), it's set
 * to `true` immediately before calling `navigate()`, and the push-effect consumes-and-clears it
 * instead of pushing.
 */
export function useHistorySync(): void {
    const screen = useGameStore(state => state.screen);
    const highscoreRaceFilter = useGameStore(state => state.highscoreRaceFilter);
    const catalog = useGameStore(state => state.catalog);
    const navigate = useGameStore(state => state.navigate);

    const fromPopStateRef = useRef(false);
    const didInitialSyncRef = useRef(false);

    // popstate (Back/Forward button) handling — registered once.
    useEffect(() => {
        function onPopState(event: PopStateEvent): void {
            const races = useGameStore.getState().catalog?.races ?? [];
            const started = useGameStore.getState().player?.started ?? false;

            fromPopStateRef.current = true;

            if (isHistoryState(event.state)) {
                navigate(event.state.screen, { raceFilter: event.state.raceFilter });
            } else {
                // No state (e.g. the very first history entry, before any pushState from this
                // hook ever ran) — fall back to parsing the current URL directly so a hard
                // refresh/back-navigation to a deep link like `/app/highscores/elf` still lands
                // correctly.
                navigate(screenFromPath(location.pathname, started), {
                    raceFilter: raceFilterFromPath(location.pathname, races),
                });
            }
        }

        window.addEventListener('popstate', onPopState);
        return () => window.removeEventListener('popstate', onPopState);
    }, [navigate]);

    // One-time reconciliation for a hard page-load landing directly on a deep link (no
    // `popstate` fires for this — it's the initial document load, not a history navigation).
    // Runs once catalog is available (i.e. after the first `hydrate`), since resolving a
    // highscores race-slug and the ambiguous "/" -> home-vs-start case both need it.
    useEffect(() => {
        if (didInitialSyncRef.current || !catalog)
            return;

        didInitialSyncRef.current = true;

        const path = location.pathname;
        if (path === APP_PREFIX || path === `${APP_PREFIX}/` || !path.startsWith(APP_PREFIX))
            return;

        const started = useGameStore.getState().player?.started ?? false;
        fromPopStateRef.current = true;
        navigate(screenFromPath(path, started), { raceFilter: raceFilterFromPath(path, catalog.races) });
    }, [catalog, navigate]);

    // screen/raceFilter change -> pushState, unless this change originated from popstate/the
    // initial-sync reconciliation above (see the loop-safety note in this function's doc comment).
    useEffect(() => {
        if (fromPopStateRef.current) {
            fromPopStateRef.current = false;
            return;
        }

        if (!catalog)
            return;

        const path = pathFor(screen, highscoreRaceFilter, catalog.races);
        if (path === null)
            return;

        window.history.pushState({ screen, raceFilter: highscoreRaceFilter } satisfies HistoryState, '', path);
    }, [screen, highscoreRaceFilter, catalog]);
}
