import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen } from '@testing-library/react';
import type { GameCatalog, PlayerSnapshot } from '@shared/contract';
import { useGameStore, type ScreenId } from '@/store/gameStore';

vi.mock('@/socket/client', () => ({ request: vi.fn() }));

const { default: App } = await import('./App');

function makeCatalog(): GameCatalog {
    return {
        version: '1.5.0',
        isRelease: false,
        commitUrl: null,
        year: 2026,
        locale: 'en-US',
        lowHealthThreshold: 0.2,
        maxLevel: 50,
        nameMinLength: 1,
        nameMaxLength: 20,
        races: [{ id: 1, label: 'Human', plural: 'Humans', emoji: '🧙', slug: 'human', enemyRaceId: 2, startHealth: 100, startAdena: 300, ambushChance: 8, regen: 1, crit: 4, backstory: '', traits: '' }],
        weapons: [{ id: 0, name: `Fists`, emoji: '👊', stat: 7, cost: 0 }],
        armors: [{ id: 0, name: `Tunic`, emoji: '🧥', stat: 2, cost: 0 }],
        foods: [{ id: 0, name: 'Ale', emoji: '🍺', stat: 4, cost: 7 }],
    };
}

function makePlayer(): PlayerSnapshot {
    return {
        revision: 1,
        started: true,
        name: 'Hero',
        raceId: 1,
        raceLabel: 'Human',
        raceEmoji: '🧑',
        health: 80,
        maxHealth: 100,
        hpPercent: 80,
        lowHealth: false,
        experience: 10,
        level: 2,
        isMaxLevel: false,
        xpCurrent: 10,
        xpRequired: 100,
        xpPercent: 10,
        xpNeeded: 90,
        adena: 500,
        weapon: null,
        armor: null,
        stats: null,
        effects: [],
        dead: false,
        ambushed: false,
        coward: false,
        cheated: false,
        deathReason: null,
        highscoreEligible: false,
        counters: { totalBattles: 0, totalAmbushes: 0, consecutiveAmbushes: 0, totalEnemiesKilled: 0 },
        lastBattle: null,
    };
}

const ALL_SCREENS: ScreenId[] = [
    'start', 'home', 'battle', 'weapons', 'armors', 'inn', 'suicide',
    'death', 'character', 'highscores', 'statistics', 'races', 'error',
];

describe('App', () => {
    beforeEach(() => {
        // useHistorySync (wired into App as of this task) calls real window.history.pushState as
        // a side effect of rendering — reset the URL before every test so one test's navigation
        // can't leak into the next test's initial-deep-link reconciliation via a stale
        // location.pathname.
        window.history.replaceState(null, '', '/');
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
            },
            false,
        );
    });

    it.each(ALL_SCREENS)('renders screen "%s" without crashing', screenId => {
        useGameStore.getState().navigate(screenId);
        expect(() => render(<App />)).not.toThrow();
    });

    it('no longer shows a "Coming soon" placeholder for any screen (every screen is now a real component)', () => {
        for (const screenId of ALL_SCREENS) {
            // Reset per-iteration: useHistorySync's one-time initial-sync effect reconciles a
            // fresh mount against the CURRENT location.pathname, which a previous iteration's
            // own pushState call would otherwise have advanced — this loop wants to test each
            // `screenId` in isolation, matching the single-mount-per-real-page-load reality this
            // hook is actually designed for.
            window.history.replaceState(null, '', '/');
            useGameStore.getState().navigate(screenId);
            const { unmount, container } = render(<App />);
            expect(container.textContent).not.toMatch(/Coming soon/);
            unmount();
        }
    });

    it('hydrate() from the store routes straight into a real, built screen (home)', () => {
        useGameStore.getState().hydrate({ player: makePlayer(), catalog: makeCatalog() });
        render(<App />);
        expect(screen.getByText(/Welcome to/)).toBeInTheDocument();
    });

    it('sets the browser tab title and in-panel heading per screen, using the exact old title strings', () => {
        const { rerender } = render(<App />);
        expect(document.title).toBe('Mini Lineage - Home Town');
        expect(screen.getByText('Home Town')).toBeInTheDocument();

        useGameStore.getState().navigate('battle');
        rerender(<App />);
        expect(document.title).toBe('Mini Lineage - Battleground');
        expect(screen.getByText('Battleground')).toBeInTheDocument();

        useGameStore.getState().navigate('weapons');
        rerender(<App />);
        expect(document.title).toBe('Mini Lineage - Weapons Shop');
        expect(screen.getByText('Weapons Shop')).toBeInTheDocument();
    });
});
