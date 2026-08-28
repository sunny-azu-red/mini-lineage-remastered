import { useEffect, useRef } from 'react';
import type { RaceView } from '@shared/contract';
import { useGameStore, type ScreenId } from '@/store/gameStore';

function pathFor(screen: ScreenId, raceFilter: number | null, races: RaceView[]): string | null {
    switch (screen) {
        case 'start':
        case 'home':
            return '/';
        case 'battle':
            return '/battle';
        case 'weapons':
            return '/shop/weapons';
        case 'armors':
            return '/shop/armors';
        case 'inn':
            return '/inn';
        case 'suicide':
            return '/suicide';
        case 'death':
            return '/death';
        case 'character':
            return '/character';
        case 'highscores': {
            if (raceFilter === null)
                return '/highscores';

            const race = races.find(r => r.id === raceFilter);
            return race ? `/highscores/${race.slug}` : '/highscores';
        }
        case 'statistics':
            return '/statistics';
        case 'races':
            return '/races';
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
    const path = pathname;

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
    const path = pathname;
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
 * The SPA now owns `/` outright (the legacy EJS app's routes and its own `/app`-prefix
 * workaround are gone — see git history for the prior parallel-run phase).
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
                // refresh/back-navigation to a deep link like `/highscores/elf` still lands
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
        if (path === '/')
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
