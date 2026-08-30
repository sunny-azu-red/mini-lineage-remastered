import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { renderHook, act } from '@testing-library/react';
import { useGameStore, type ScreenId } from '@/store/gameStore';
import { useHistorySync } from '@/hooks/useHistorySync';
import { makeCatalog, makePlayer } from '../factories';

// The defaults this file's assertions were written against.
const localCatalog = (o: Partial<Parameters<typeof makeCatalog>[0]> = {}) =>
    makeCatalog({ nameMinLength: 2, nameMaxLength: 16, races: [ { id: 1, label: 'Human', plural: 'Humans', emoji: '🧑', slug: 'human', enemyRaceId: 2, startHealth: 100, startAdena: 50, ambushChance: 5, regen: 2, crit: 5, backstory: '', traits: '', }, ], ...o });

function resetStore(overrides: Partial<ReturnType<typeof useGameStore.getState>> = {}) {
    useGameStore.setState(
        {
            status: 'ready',
            player: makePlayer(),
            catalog: localCatalog(),
            screen: 'home',
            highscoreRaceFilter: null,
            flash: null,
            lastBattle: null,
            notice: null,
            soundEnabled: false,
            ...overrides,
        },
        false,
    );
}

let pushSpy: ReturnType<typeof vi.spyOn>;

describe('useHistorySync', () => {
    beforeEach(() => {
        window.history.replaceState(null, '', '/');
        pushSpy = vi.spyOn(window.history, 'pushState');
        resetStore();
    });

    afterEach(() => {
        pushSpy.mockRestore();
    });

    it('pushes the path matching the current screen on mount', () => {
        renderHook(() => useHistorySync());
        expect(pushSpy).toHaveBeenCalledWith(
            expect.objectContaining({ screen: 'home', raceFilter: null }),
            '',
            '/',
        );
    });

    it('pushes a new path whenever the store screen changes', () => {
        renderHook(() => useHistorySync());
        pushSpy.mockClear();

        act(() => {
            useGameStore.getState().navigate('battle');
        });

        expect(pushSpy).toHaveBeenCalledWith(expect.anything(), '', '/battle');
    });

    it('resolves a highscores raceFilter to its slug-based path via catalog.races', () => {
        renderHook(() => useHistorySync());
        pushSpy.mockClear();

        act(() => {
            useGameStore.getState().navigate('highscores', { raceFilter: 1 });
        });

        expect(pushSpy).toHaveBeenCalledWith(expect.anything(), '', '/highscores/human');
    });

    it('does not push a path for the "error" screen (no link-worthy URL)', () => {
        renderHook(() => useHistorySync());
        pushSpy.mockClear();

        act(() => {
            useGameStore.getState().navigate('error');
        });

        expect(pushSpy).not.toHaveBeenCalled();
    });

    it('a popstate event carrying history state navigates the store to the encoded screen/filter', () => {
        resetStore({ player: makePlayer({ started: false, name: null }) });
        renderHook(() => useHistorySync());

        act(() => {
            window.dispatchEvent(new PopStateEvent('popstate', { state: { screen: 'races', raceFilter: null } }));
        });

        expect(useGameStore.getState().screen).toBe('races');
    });

    it('a popstate event with no state falls back to parsing location.pathname', () => {
        resetStore({ player: makePlayer({ started: false, name: null }) });
        renderHook(() => useHistorySync());

        act(() => {
            // Simulates landing on a history entry that predates this hook ever calling
            // pushState (e.g. the very first page load) — no `event.state`, so the handler must
            // recover the screen by parsing the URL instead.
            window.history.pushState(null, '', '/statistics');
            window.dispatchEvent(new PopStateEvent('popstate', { state: null }));
        });

        expect(useGameStore.getState().screen).toBe('statistics');
    });

    // Regression for a subtle leak: the sync effect consumes `fromHistoryRef`, but its other deps
    // are the screen/filter/catalog. When a history navigation resolves to the screen ALREADY
    // showing — which pinScreen's redirects make routine — nothing those deps watch changes, the
    // effect never runs, the flag stays set, and it silently swallows the NEXT genuine
    // navigation's pushState. History then diverges from the store until a reload.
    it('still pushes for a later navigation after a history event that changed nothing', () => {
        resetStore({ player: makePlayer({ started: true, dead: false }), screen: 'home' });
        renderHook(() => useHistorySync());
        pushSpy.mockClear();

        act(() => {
            // Statistics is blocked for a started player, so this resolves right back to 'home'.
            window.dispatchEvent(new PopStateEvent('popstate', { state: { screen: 'statistics', raceFilter: null } }));
        });
        expect(useGameStore.getState().screen).toBe('home');

        act(() => {
            useGameStore.getState().navigate('inn');
        });

        expect(pushSpy).toHaveBeenCalledWith(expect.objectContaining({ screen: 'inn' }), '', '/inn');
    });

    // When a rule overrides the screen the entry encoded, the URL must be corrected in place —
    // otherwise the address bar claims /death while the page shows Home. replaceState, not push:
    // we are standing ON that entry, and pushing would duplicate it and break Back.
    it('rewrites the current history entry when a rule redirects away from it', () => {
        resetStore({ player: makePlayer({ started: true, dead: false }), screen: 'home' });
        renderHook(() => useHistorySync());

        // Stand on a /death entry, the way Back would leave us, AFTER mount so the mount's own
        // push doesn't pre-correct the URL.
        window.history.replaceState(null, '', '/death');
        const replaceSpy = vi.spyOn(window.history, 'replaceState');
        pushSpy.mockClear();

        act(() => {
            window.dispatchEvent(new PopStateEvent('popstate', { state: { screen: 'death', raceFilter: null } }));
        });

        expect(useGameStore.getState().screen).toBe('home');
        expect(replaceSpy).toHaveBeenCalledWith(expect.objectContaining({ screen: 'home' }), '', '/');
        expect(pushSpy).not.toHaveBeenCalled();
        replaceSpy.mockRestore();
    });

    it('does not re-pushState in response to a popstate-triggered navigation (loop guard)', () => {
        renderHook(() => useHistorySync());

        act(() => {
            useGameStore.getState().navigate('battle');
        });
        act(() => {
            useGameStore.getState().navigate('inn');
        });

        const callsSoFar = pushSpy.mock.calls.length;

        act(() => {
            window.dispatchEvent(new PopStateEvent('popstate', { state: { screen: 'battle', raceFilter: null } }));
        });

        // The popstate-triggered navigate() must not cause an additional pushState — otherwise
        // Back would immediately push a new (duplicate) history entry on top of the one it just
        // navigated to, breaking Back/Forward.
        expect(pushSpy.mock.calls.length).toBe(callsSoFar);
        expect(useGameStore.getState().screen).toBe('battle');

        // And a bounded, small number of total pushState calls across this whole sequence —
        // proves there's no runaway push<->popstate feedback loop.
        expect(pushSpy.mock.calls.length).toBeLessThanOrEqual(4);
    });

    it('reconciles a hard page-load landing directly on a deep link once catalog is available', () => {
        window.history.replaceState(null, '', '/highscores/human');
        // Simulate the pre-hydrate state: no catalog yet, default screen.
        resetStore({ catalog: null, screen: 'start' });

        const { rerender } = renderHook(() => useHistorySync());
        expect(useGameStore.getState().screen).toBe('start');

        // Hydrate lands (catalog becomes available) — the one-time initial-sync effect should
        // now reconcile the store's screen/filter with the URL it was actually loaded at.
        act(() => {
            resetStore({ screen: 'start' });
        });
        rerender();

        expect(useGameStore.getState().screen).toBe('highscores');
        expect(useGameStore.getState().highscoreRaceFilter).toBe(1);
    });

    it('clamps a deep link to a disallowed screen (e.g. /battle) to "start" for an unstarted player, via the initial-sync reconciliation', () => {
        window.history.replaceState(null, '', '/battle');
        resetStore({ catalog: null, screen: 'start', player: makePlayer({ started: false }) });

        const { rerender } = renderHook(() => useHistorySync());
        expect(useGameStore.getState().screen).toBe('start');

        act(() => {
            resetStore({ screen: 'start', player: makePlayer({ started: false }) });
        });
        rerender();

        expect(useGameStore.getState().screen).toBe('start');
    });

    it('does NOT clamp an allowed screen (e.g. /highscores) for the same unstarted player', () => {
        window.history.replaceState(null, '', '/highscores');
        resetStore({ catalog: null, screen: 'start', player: makePlayer({ started: false }) });

        const { rerender } = renderHook(() => useHistorySync());

        act(() => {
            resetStore({ screen: 'start', player: makePlayer({ started: false }) });
        });
        rerender();

        expect(useGameStore.getState().screen).toBe('highscores');
    });

    it('clamps a popstate-resolved deep link to "start" for an unstarted player', () => {
        resetStore({ player: makePlayer({ started: false }), screen: 'start' });
        renderHook(() => useHistorySync());

        act(() => {
            window.history.pushState(null, '', '/battle');
            window.dispatchEvent(new PopStateEvent('popstate', { state: null }));
        });

        expect(useGameStore.getState().screen).toBe('start');
    });

    // Regression: the screen encoded in a history entry used to be trusted verbatim, so Back
    // could put a player with no character onto Battle/Inn/Death with live action buttons —
    // the one route around the old cheatMiddleware's allowlist that survived the rewrite.
    it('clamps a screen carried in real history state, exactly like a parsed path', () => {
        resetStore({ player: makePlayer({ started: false, name: null }), screen: 'start' });
        renderHook(() => useHistorySync());

        act(() => {
            window.dispatchEvent(new PopStateEvent('popstate', { state: { screen: 'battle', raceFilter: null } }));
        });

        expect(useGameStore.getState().screen).toBe('start');
    });

    it('clamps a history entry encoding the death screen when the character is alive', () => {
        resetStore({ player: makePlayer({ started: true, dead: false }), screen: 'home' });
        renderHook(() => useHistorySync());

        act(() => {
            window.dispatchEvent(new PopStateEvent('popstate', { state: { screen: 'death', raceFilter: null } }));
        });

        expect(useGameStore.getState().screen).toBe('home');
    });

    // Every screen -> path mapping, exhaustively. Each case starts from the 'error' screen,
    // whose pathFor() is deliberately null (no pushState on mount), so the single push observed
    // afterwards is unambiguously the one produced by the navigation under test.
    //
    // Each case also carries the player state in which that screen is REACHABLE, because
    // pinScreen enforces the old cheatMiddleware's rules: the pre-character screens need a
    // visitor with no character, and 'death' needs a corpse. Navigating with the wrong state
    // would be redirected, and we'd be testing the redirect rather than the path mapping.
    const ALIVE = { started: true, dead: false } as const;
    const UNSTARTED = { started: false, name: null } as const;
    const DEAD = { started: true, dead: true } as const;

    describe('screen -> path (pathFor)', () => {
        it.each([
            ['start', '/', UNSTARTED],
            ['home', '/', ALIVE],
            ['battle', '/battle', ALIVE],
            ['weapons', '/shop/weapons', ALIVE],
            ['armors', '/shop/armors', ALIVE],
            ['inn', '/inn', ALIVE],
            ['suicide', '/suicide', ALIVE],
            ['death', '/death', DEAD],
            ['character', '/character', ALIVE],
            ['highscores', '/highscores', ALIVE],
            ['statistics', '/statistics', UNSTARTED],
            ['races', '/races', UNSTARTED],
        ] as const)('navigating to "%s" pushes %s', (screenId, path, playerState) => {
            resetStore({ screen: 'error', player: makePlayer(playerState) });
            renderHook(() => useHistorySync());
            expect(pushSpy).not.toHaveBeenCalled();

            act(() => {
                useGameStore.getState().navigate(screenId);
            });

            expect(pushSpy).toHaveBeenCalledWith(
                expect.objectContaining({ screen: screenId, raceFilter: null }),
                '',
                path,
            );
        });

        it('falls back to the unfiltered /highscores path when the raceFilter matches no known race', () => {
            resetStore({ screen: 'error' });
            renderHook(() => useHistorySync());

            act(() => {
                useGameStore.getState().navigate('highscores', { raceFilter: 999 });
            });

            expect(pushSpy).toHaveBeenCalledWith(expect.anything(), '', '/highscores');
        });

        it('pushes nothing at all for a screen id with no mapped path', () => {
            resetStore({ screen: 'error' });
            renderHook(() => useHistorySync());

            act(() => {
                useGameStore.getState().navigate('not-a-real-screen' as ScreenId);
            });

            expect(pushSpy).not.toHaveBeenCalled();
        });
    });

    // The reverse mapping, exercised through the stateless-popstate path (the same parser also
    // backs the initial hard-load deep-link reconciliation).
    describe('path -> screen (screenFromPath)', () => {
        it.each([
            ['/', 'home', ALIVE],
            ['/battle', 'battle', ALIVE],
            ['/shop/weapons', 'weapons', ALIVE],
            ['/shop/armors', 'armors', ALIVE],
            ['/inn', 'inn', ALIVE],
            ['/suicide', 'suicide', ALIVE],
            ['/death', 'death', DEAD],
            ['/character', 'character', ALIVE],
            ['/highscores', 'highscores', ALIVE],
            ['/highscores/human', 'highscores', ALIVE],
            ['/statistics', 'statistics', UNSTARTED],
            ['/races', 'races', UNSTARTED],
        ] as const)('a stateless popstate at %s resolves to the "%s" screen', (path, expected, playerState) => {
            resetStore({ screen: 'error', player: makePlayer(playerState) });
            renderHook(() => useHistorySync());

            act(() => {
                window.history.pushState(null, '', path);
                window.dispatchEvent(new PopStateEvent('popstate', { state: null }));
            });

            expect(useGameStore.getState().screen).toBe(expected);
        });

        it('resolves a known highscores slug to its race id, and an unknown one to no filter', () => {
            resetStore({ screen: 'error', highscoreRaceFilter: 1 });
            renderHook(() => useHistorySync());

            act(() => {
                window.history.pushState(null, '', '/highscores/human');
                window.dispatchEvent(new PopStateEvent('popstate', { state: null }));
            });
            expect(useGameStore.getState().highscoreRaceFilter).toBe(1);

            act(() => {
                window.history.pushState(null, '', '/highscores/gnome');
                window.dispatchEvent(new PopStateEvent('popstate', { state: null }));
            });
            expect(useGameStore.getState().screen).toBe('highscores');
            expect(useGameStore.getState().highscoreRaceFilter).toBeNull();
        });

        it('sends a started player to "home" for an unrecognized path', () => {
            resetStore({ screen: 'inn' });
            renderHook(() => useHistorySync());

            act(() => {
                window.history.pushState(null, '', '/there/is/no/such/page');
                window.dispatchEvent(new PopStateEvent('popstate', { state: null }));
            });

            expect(useGameStore.getState().screen).toBe('home');
        });

        it('sends an unstarted visitor to "start" for that same unrecognized path', () => {
            resetStore({ screen: 'races', player: makePlayer({ started: false }) });
            renderHook(() => useHistorySync());

            act(() => {
                window.history.pushState(null, '', '/there/is/no/such/page');
                window.dispatchEvent(new PopStateEvent('popstate', { state: null }));
            });

            expect(useGameStore.getState().screen).toBe('start');
        });

        it('resolves "/" to "start" rather than "home" for an unstarted visitor', () => {
            resetStore({ screen: 'races', player: makePlayer({ started: false }) });
            renderHook(() => useHistorySync());

            act(() => {
                window.history.pushState(null, '', '/');
                window.dispatchEvent(new PopStateEvent('popstate', { state: null }));
            });

            expect(useGameStore.getState().screen).toBe('start');
        });

        // cheatMiddleware's old allowlist, ported: an unstarted player deep-linking into any
        // in-game screen is clamped back to the Game Start screen.
        it.each([
            '/battle', '/shop/weapons', '/shop/armors', '/inn', '/suicide', '/death', '/character',
        ] as const)('clamps an unstarted visitor landing on %s back to "start"', path => {
            resetStore({ screen: 'start', player: makePlayer({ started: false }) });
            renderHook(() => useHistorySync());

            act(() => {
                window.history.pushState(null, '', path);
                window.dispatchEvent(new PopStateEvent('popstate', { state: null }));
            });

            expect(useGameStore.getState().screen).toBe('start');
        });

        // Pre-hydrate: a popstate can fire before any catalog/player exists at all, so both
        // lookups fall back (no races to resolve a slug against, and "not started").
        it('survives a popstate that lands before catalog/player exist, clamping to "start"', () => {
            resetStore({ screen: 'error', catalog: null, player: null });
            renderHook(() => useHistorySync());

            act(() => {
                window.history.pushState(null, '', '/highscores/human');
                window.dispatchEvent(new PopStateEvent('popstate', { state: null }));
            });

            expect(useGameStore.getState().screen).toBe('highscores');
            expect(useGameStore.getState().highscoreRaceFilter).toBeNull();
        });

        it('reconciles an initial deep link with no player yet, treating it as not started', () => {
            window.history.replaceState(null, '', '/statistics');
            resetStore({ catalog: null, player: null, screen: 'start' });

            const { rerender } = renderHook(() => useHistorySync());
            act(() => {
                resetStore({ player: null, screen: 'start' });
            });
            rerender();

            expect(useGameStore.getState().screen).toBe('statistics');
        });

        it.each([
            ['/statistics', 'statistics'],
            ['/races', 'races'],
            ['/highscores', 'highscores'],
        ] as const)('leaves an unstarted visitor on the allowlisted %s deep link', (path, expected) => {
            resetStore({ screen: 'start', player: makePlayer({ started: false }) });
            renderHook(() => useHistorySync());

            act(() => {
                window.history.pushState(null, '', path);
                window.dispatchEvent(new PopStateEvent('popstate', { state: null }));
            });

            expect(useGameStore.getState().screen).toBe(expected);
        });
    });
});
