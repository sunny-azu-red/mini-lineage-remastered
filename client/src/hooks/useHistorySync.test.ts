import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { renderHook, act } from '@testing-library/react';
import type { GameCatalog, PlayerSnapshot } from '@shared/contract';
import { useGameStore } from '@/store/gameStore';
import { useHistorySync } from './useHistorySync';

function makeCatalog(): GameCatalog {
    return {
        version: '1.5.0', isRelease: false, commitUrl: null, year: 2026, locale: 'en-US',
        lowHealthThreshold: 0.2, maxLevel: 50, nameMinLength: 2, nameMaxLength: 16,
        races: [
            {
                id: 1, label: 'Human', plural: 'Humans', emoji: '🧑', slug: 'human',
                enemyRaceId: 2, startHealth: 100, startAdena: 50, ambushChance: 5, regen: 2, crit: 5,
                backstory: '', traits: '',
            },
        ],
        weapons: [], armors: [], foods: [],
    };
}

function makePlayer(overrides: Partial<PlayerSnapshot> = {}): PlayerSnapshot {
    return {
        revision: 1, started: true, name: 'Hero', raceId: 1, raceLabel: 'Human', raceEmoji: '🧑',
        health: 80, maxHealth: 100, hpPercent: 80, lowHealth: false,
        experience: 10, level: 2, isMaxLevel: false, xpCurrent: 10, xpRequired: 100, xpPercent: 10, xpNeeded: 90,
        adena: 500, weapon: null, armor: null, stats: null, effects: [],
        dead: false, ambushed: false, coward: false, cheated: false, deathReason: null, highscoreEligible: false,
        counters: { totalBattles: 0, totalAmbushes: 0, consecutiveAmbushes: 0, totalEnemiesKilled: 0 },
        lastBattle: null,
        ...overrides,
    };
}

function resetStore(overrides: Partial<ReturnType<typeof useGameStore.getState>> = {}) {
    useGameStore.setState(
        {
            status: 'ready',
            player: makePlayer(),
            catalog: makeCatalog(),
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
        renderHook(() => useHistorySync());

        act(() => {
            window.dispatchEvent(new PopStateEvent('popstate', { state: { screen: 'races', raceFilter: null } }));
        });

        expect(useGameStore.getState().screen).toBe('races');
    });

    it('a popstate event with no state falls back to parsing location.pathname', () => {
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

    it('does not clamp a screen carried in real history state (only screenFromPath results are clamped)', () => {
        resetStore({ player: makePlayer({ started: false }), screen: 'start' });
        renderHook(() => useHistorySync());

        act(() => {
            window.dispatchEvent(new PopStateEvent('popstate', { state: { screen: 'battle', raceFilter: null } }));
        });

        expect(useGameStore.getState().screen).toBe('battle');
    });
});
