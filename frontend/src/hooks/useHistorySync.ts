import { useEffect, useRef, useState } from 'react';
import type { RaceView } from '@shared/contract';
import { useGameStore, type ScreenId } from '@/store/gameStore';
import { pathFor, screenFromPath, raceFilterFromPath } from '@/routes';

interface HistoryState {
    screen: ScreenId;
    raceFilter: number | null;
}

function isHistoryState(value: unknown): value is HistoryState {
    return typeof value === 'object' && value !== null && 'screen' in value;
}

/**
 * Maps `store.screen`/`highscoreRaceFilter` <-> browser history, giving Back/Forward support
 * with no router dependency. Call once, from App.tsx.
 *
 * Loop safety: a screen change pushes state, and a popstate navigates the store — which would
 * re-trigger the push and clobber the entry just navigated to. `fromHistoryRef` marks
 * history-originated (and initial-reconciliation) navigations so the sync effect corrects the
 * current entry in place instead of pushing a new one.
 *
 * Access rules are NOT enforced here — `pinScreen` owns all of them, and every path in this hook
 * reaches it through `navigate()`. That is what makes Back/Forward obey exactly the same rules as
 * a typed URL.
 */
export function useHistorySync(): void {
    const screen = useGameStore(state => state.screen);
    const highscoreRaceFilter = useGameStore(state => state.highscoreRaceFilter);
    const catalog = useGameStore(state => state.catalog);
    const navigate = useGameStore(state => state.navigate);

    const fromHistoryRef = useRef(false);
    const didInitialSyncRef = useRef(false);
    // Bumped by every history-originated navigation purely to guarantee the sync effect below
    // re-runs. Without it, a navigation that resolves to the screen already showing (very common
    // now that pinScreen redirects) changes none of that effect's other deps, so it never runs,
    // never clears `fromHistoryRef`, and silently swallows the NEXT genuine navigation's push.
    const [historySeq, setHistorySeq] = useState(0);

    /** Navigates from a history event — never pushes a new entry, only corrects the current one. */
    function navigateFromHistory(screen: ScreenId, raceFilter: number | null): void {
        fromHistoryRef.current = true;
        setHistorySeq(seq => seq + 1);
        navigate(screen, { raceFilter });
    }

    /** Resolves a URL to a screen + race filter and navigates there. */
    function navigateToPath(pathname: string, races: RaceView[]): void {
        navigateFromHistory(screenFromPath(pathname), raceFilterFromPath(pathname, races));
    }

    useEffect(() => {
        function onPopState(event: PopStateEvent): void {
            if (isHistoryState(event.state)) {
                // The encoded screen is NOT trusted — it goes through navigate() -> pinScreen
                // like everything else, so Back obeys the same access rules as a deep link.
                navigateFromHistory(event.state.screen, event.state.raceFilter);
                return;
            }

            // No state (the first history entry, before this hook ever pushed) — parse the URL
            // so a hard refresh or back-navigation onto a deep link still lands correctly.
            navigateToPath(location.pathname, useGameStore.getState().catalog?.races ?? []);
        }

        window.addEventListener('popstate', onPopState);
        return () => window.removeEventListener('popstate', onPopState);
        // eslint-disable-next-line react-hooks/exhaustive-deps
    }, [navigate]);

    // One-shot reconciliation for a hard load landing on a deep link — no popstate fires for the
    // initial document load. `hydrate` already resolved the SCREEN from the URL, so for a socket
    // boot this usually re-navigates to where we already are (a no-op that fires no
    // `player:screen`). It still earns its keep: it resolves a `/highscores/<slug>` race filter,
    // which needs `catalog.races`, and it rewrites the URL when pinScreen redirected away from
    // what was typed. Waits for `catalog` for that race lookup.
    useEffect(() => {
        if (didInitialSyncRef.current || !catalog)
            return;

        didInitialSyncRef.current = true;
        if (location.pathname !== '/')
            navigateToPath(location.pathname, catalog.races);
        // eslint-disable-next-line react-hooks/exhaustive-deps
    }, [catalog, navigate]);

    useEffect(() => {
        // Consume the flag unconditionally, BEFORE any early return — leaving it set would
        // swallow the next genuine navigation's push. `historySeq` is in the deps precisely so
        // this runs even when the navigation resolved to the screen already showing.
        const fromHistory = fromHistoryRef.current;
        fromHistoryRef.current = false;

        if (!catalog)
            return;

        const path = pathFor(screen, highscoreRaceFilter, catalog.races);
        if (path === null)
            return;

        const entry = { screen, raceFilter: highscoreRaceFilter } satisfies HistoryState;

        if (fromHistory) {
            // We are already standing on this history entry. If pinScreen redirected away from
            // what it encoded, rewrite it in place so the URL stops lying — pushing would
            // duplicate the entry and break Back. replaceState fires no popstate, so no loop.
            if (path !== location.pathname)
                window.history.replaceState(entry, '', path);

            return;
        }

        window.history.pushState(entry, '', path);
    }, [screen, highscoreRaceFilter, catalog, historySeq]);
}
