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
 * Maps `store.screen`/`highscoreRaceFilter` <-> browser history, giving Back/Forward support with
 * no router dependency. Call once, from App.tsx. Access rules are NOT enforced here — `pinScreen`
 * (gameStore.ts) owns all of them, and every path here reaches it through `navigate()`.
 */
export function useHistorySync(): void {
    const screen = useGameStore(state => state.screen);
    const highscoreRaceFilter = useGameStore(state => state.highscoreRaceFilter);
    const catalog = useGameStore(state => state.catalog);
    const navigate = useGameStore(state => state.navigate);

    // Marks a history-originated (or initial-reconciliation) navigation so the sync effect below
    // corrects the current entry in place instead of pushing a new one — otherwise a popstate's
    // own navigate() call would re-trigger a push and clobber the entry just navigated to.
    const fromHistoryRef = useRef(false);
    const didInitialSyncRef = useRef(false);
    // Bumped on every history-originated navigation to guarantee the sync effect re-runs even when
    // it resolves to the screen already showing (common now that pinScreen redirects) — otherwise
    // that effect never clears `fromHistoryRef` and silently swallows the NEXT real navigation.
    const [historySeq, setHistorySeq] = useState(0);

    function navigateFromHistory(screen: ScreenId, raceFilter: number | null): void {
        fromHistoryRef.current = true;
        setHistorySeq(seq => seq + 1);
        navigate(screen, { raceFilter });
    }

    function navigateToPath(pathname: string, races: RaceView[]): void {
        navigateFromHistory(screenFromPath(pathname), raceFilterFromPath(pathname, races));
    }

    useEffect(() => {
        function onPopState(event: PopStateEvent): void {
            if (isHistoryState(event.state)) {
                navigateFromHistory(event.state.screen, event.state.raceFilter);
                return;
            }

            // No state (the first history entry, before this hook ever pushed) — parse the URL so
            // a hard refresh or back-navigation onto a deep link still lands correctly.
            navigateToPath(location.pathname, useGameStore.getState().catalog?.races ?? []);
        }

        window.addEventListener('popstate', onPopState);
        return () => window.removeEventListener('popstate', onPopState);
        // eslint-disable-next-line react-hooks/exhaustive-deps
    }, [navigate]);

    // One-shot reconciliation for a hard load landing on a deep link (no popstate fires for the
    // initial document load). `hydrate` already resolved the screen from the URL, so this usually
    // re-navigates to where we already are; it still resolves a highscores race-filter slug and
    // rewrites the URL if pinScreen redirected away from what was typed.
    useEffect(() => {
        if (didInitialSyncRef.current || !catalog)
            return;

        didInitialSyncRef.current = true;
        if (location.pathname !== '/')
            navigateToPath(location.pathname, catalog.races);
        // eslint-disable-next-line react-hooks/exhaustive-deps
    }, [catalog, navigate]);

    useEffect(() => {
        // Consumed unconditionally, before any early return, or it would swallow the next
        // genuine navigation's push.
        const fromHistory = fromHistoryRef.current;
        fromHistoryRef.current = false;

        if (!catalog)
            return;

        const path = pathFor(screen, highscoreRaceFilter, catalog.races);
        if (path === null)
            return;

        const entry = { screen, raceFilter: highscoreRaceFilter } satisfies HistoryState;

        if (fromHistory) {
            // Already standing on this entry; rewrite in place only if pinScreen redirected away
            // from what it encoded. replaceState fires no popstate, so this can't loop.
            if (path !== location.pathname)
                window.history.replaceState(entry, '', path);

            return;
        }

        window.history.pushState(entry, '', path);
    }, [screen, highscoreRaceFilter, catalog, historySeq]);
}
