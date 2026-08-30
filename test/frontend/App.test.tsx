import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen } from '@testing-library/react';
import { useGameStore, type ScreenId } from '@/store/gameStore';
import { makeCatalog, makePlayer } from './factories';

// The defaults this file's assertions were written against.
const localCatalog = (o: Partial<Parameters<typeof makeCatalog>[0]> = {}) =>
    makeCatalog({ races: [{ id: 1, label: 'Human', plural: 'Humans', emoji: '🧙', slug: 'human', enemyRaceId: 2, startHealth: 100, startAdena: 300, ambushChance: 8, regen: 1, crit: 4, backstory: '', traits: '' }], weapons: [{ id: 0, name: `Fists`, emoji: '👊', stat: 7, cost: 0 }], armors: [{ id: 0, name: `Tunic`, emoji: '🧥', stat: 2, cost: 0 }], foods: [{ id: 0, name: 'Ale', emoji: '🍺', stat: 4, cost: 7 }], ...o });

const { socketEmitMock, requestMock } = vi.hoisted(() => ({
    socketEmitMock: vi.fn(),
    // navigate()/hydrate() always call .then() on this now (to apply the player:screen ack to
    // their own store) — needs a resolved default so tests that don't care about the response
    // don't crash on `undefined.then`.
    requestMock: vi.fn().mockResolvedValue({ ok: false, error: { code: 'INTERNAL', message: 'mock default' } }),
}));
vi.mock('@/socket/client', () => ({ request: requestMock, socket: { emit: socketEmitMock } }));

const { default: App } = await import('@/App');

// Each screen paired with the player state in which it is actually REACHABLE — pinScreen
// redirects away from the rest, and a loop that lands on Home every time would be asserting
// nothing about the screen it names.
const ALL_SCREENS: Array<[ScreenId, Partial<Parameters<typeof makePlayer>[0]>]> = [
    ['start', { started: false, name: null }],
    ['home', { started: true, dead: false }],
    ['battle', { started: true, dead: false }],
    ['weapons', { started: true, dead: false }],
    ['armors', { started: true, dead: false }],
    ['inn', { started: true, dead: false }],
    ['suicide', { started: true, dead: false }],
    ['death', { started: true, dead: true }],
    ['character', { started: true, dead: false }],
    ['highscores', { started: true, dead: false }],
    ['statistics', { started: false, name: null }],
    ['races', { started: false, name: null }],
    ['error', { started: false, name: null }],
];

describe('App', () => {
    beforeEach(() => {
        // useHistorySync (wired into App as of this task) calls real window.history.pushState as
        // a side effect of rendering — reset the URL before every test so one test's navigation
        // can't leak into the next test's initial-deep-link reconciliation via a stale
        // location.pathname.
        window.history.replaceState(null, '', '/');
        socketEmitMock.mockReset();
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
            },
            false,
        );
    });

    it.each(ALL_SCREENS)('renders screen "%s" without crashing', (screenId, playerState) => {
        useGameStore.setState({ player: makePlayer(playerState) }, false);
        useGameStore.getState().navigate(screenId);

        expect(useGameStore.getState().screen).toBe(screenId);
        expect(() => render(<App />)).not.toThrow();
    });

    it('no longer shows a "Coming soon" placeholder for any screen (every screen is now a real component)', () => {
        for (const [screenId, playerState] of ALL_SCREENS) {
            // Reset per-iteration: useHistorySync's one-time initial-sync effect reconciles a
            // fresh mount against the CURRENT location.pathname, which a previous iteration's
            // own pushState call would otherwise have advanced — this loop wants to test each
            // `screenId` in isolation, matching the single-mount-per-real-page-load reality this
            // hook is actually designed for.
            window.history.replaceState(null, '', '/');
            useGameStore.setState({ player: makePlayer(playerState) }, false);
            useGameStore.getState().navigate(screenId);
            const { unmount, container } = render(<App />);
            expect(container.textContent).not.toMatch(/Coming soon/);
            unmount();
        }
    });

    it('hydrate() from the store routes straight into a real, built screen (home)', () => {
        useGameStore.getState().hydrate({ player: makePlayer(), catalog: localCatalog() });
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

    it('mounts the global Konami-code relay (useKonamiRelay): a keydown on window emits input to the server', () => {
        render(<App />);

        window.dispatchEvent(new KeyboardEvent('keydown', { key: 'ArrowUp' }));

        expect(socketEmitMock).toHaveBeenCalledWith('input', { key: 'arrowup' });
    });
});
