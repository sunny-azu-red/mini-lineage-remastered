import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, waitFor, within } from '@testing-library/react';
import type { ScreenId } from '@shared/contract';

const { socketEmitMock, requestMock } = vi.hoisted(() => ({
    socketEmitMock: vi.fn(),
    requestMock: vi.fn(),
}));
vi.mock('@/socket/client', () => ({ request: requestMock, socket: { emit: socketEmitMock } }));

const { useGameStore } = await import('@/store/gameStore');
const { default: App } = await import('@/App');
const { makePlayer, makeCatalog } = await import('./factories');

/**
 * Liveness: no reachable state may be a dead end.
 *
 * `pinScreen` redirects, and several screens self-blank for the wrong player state. Those two
 * mechanisms can conspire: pin someone to a screen that then refuses to render them, and they
 * are stranded — every navigation bounces straight back to the blank page, with no way out but
 * clearing cookies. That is exactly what a dead-and-ambushed player used to hit.
 *
 * So for every player state, whatever screen they are pinned to must offer at least one enabled
 * control that makes progress. This asserts the property directly instead of trusting that the
 * redirect table and the per-screen guards happen to agree.
 */

const CATALOG = makeCatalog({
    // Both sides of the rivalry: CharacterScreen resolves the player's race AND, through its
    // `enemyRaceId`, the opponent's — a catalog with only one race makes it blank.
    races: [
        { id: 0, label: 'Human', plural: 'Humans', emoji: '🧙', slug: 'human', enemyRaceId: 1, startHealth: 100, startAdena: 300, ambushChance: 8, regen: 1, crit: 4, backstory: 'b', traits: 't' },
        { id: 1, label: 'Orc', plural: 'Orcs', emoji: '🧟', slug: 'orc', enemyRaceId: 0, startHealth: 150, startAdena: 250, ambushChance: 16, regen: 0, crit: 0, backstory: 'b', traits: 't' },
    ],
    weapons: [{ id: 0, name: 'Fists', emoji: '👊', stat: 7, cost: 0 }, { id: 1, name: 'Needle', emoji: '🗡️', stat: 16, cost: 300 }],
    armors: [{ id: 0, name: 'Tunic', emoji: '🧥', stat: 2, cost: 0 }, { id: 1, name: 'Leathers', emoji: '🥋', stat: 10, cost: 500 }],
    foods: [{ id: 0, name: 'Ale', emoji: '🍺', stat: 4, cost: 7 }],
});

// `buildPlayerSnapshot` always fills these in for a started player; the shared factory defaults
// them to null (the never-started shape), which CharacterScreen correctly refuses to render.
const EQUIPPED = {
    weapon: { id: 1, name: 'Needle', emoji: '🗡️', stat: 16, cost: 300 },
    armor: { id: 1, name: 'Leathers', emoji: '🥋', stat: 10, cost: 500 },
    stats: { attack: 16, defense: 10, crit: 4, regen: 1, ambushRisk: 8 },
    raceId: 0,
} as const;

/** Every player state the game can actually be in, including the awkward combinations. */
const PLAYER_STATES = {
    'no character yet': { started: false, name: null, raceId: null },
    'alive and well': { ...EQUIPPED, started: true, dead: false, ambushed: false },
    'alive, ambushed': { ...EQUIPPED, started: true, dead: false, ambushed: true },
    'alive, low health': { ...EQUIPPED, started: true, dead: false, ambushed: false, health: 1, hpPercent: 1, lowHealth: true },
    'dead': { ...EQUIPPED, started: true, dead: true, deathReason: 'You fell.', highscoreEligible: true },
    'dead as a coward': { ...EQUIPPED, started: true, dead: true, coward: true, deathReason: 'Cowardly.', highscoreEligible: false },
    'dead as a cheater': { ...EQUIPPED, started: true, dead: true, cheated: true, deathReason: 'Heresy.', highscoreEligible: false },
    // killPlayer does not clear `ambushed`, so a corpse can still carry the flag.
    'dead AND ambushed': { ...EQUIPPED, started: true, dead: true, ambushed: true, deathReason: 'You fell.', highscoreEligible: true },
} as const;

// Everywhere the player could be trying to go when a rule catches them.
const ATTEMPTED: ScreenId[] = [
    'start', 'home', 'battle', 'weapons', 'armors', 'inn', 'suicide',
    'death', 'character', 'highscores', 'statistics', 'races',
];

beforeEach(() => {
    requestMock.mockResolvedValue({ ok: false, error: { code: 'INTERNAL', message: 'mock' } });
    window.history.replaceState(null, '', '/');
    useGameStore.setState(
        { status: 'ready', player: null, catalog: CATALOG, screen: 'start', highscoreRaceFilter: null, flash: null, lastBattle: null, notice: null, soundEnabled: false },
        false,
    );
});

/** The controls inside the panel body — the screen's own, excluding the always-present chrome. */
function screenControls(container: HTMLElement): HTMLElement[] {
    const body = container.querySelector('.panel-body');
    if (!body)
        return [];

    return [
        ...within(body as HTMLElement).queryAllByRole('button'),
        ...within(body as HTMLElement).queryAllByRole('link'),
        ...within(body as HTMLElement).queryAllByRole('combobox'),
    ].filter(el => !el.hasAttribute('disabled'));
}

describe('no state is a dead end', () => {
    for (const [label, state] of Object.entries(PLAYER_STATES)) {
        it.each(ATTEMPTED)(`a player who is ${label}, trying to reach %s, still has a way forward`, async (attempted) => {
            useGameStore.setState({ player: makePlayer(state) }, false);
            useGameStore.getState().navigate(attempted);

            const { container } = render(<App />);

            // Screens that fetch on mount render nothing until that settles — wait it out, then
            // assert they landed somewhere with something to do.
            await waitFor(() => {
                expect(container.querySelector('.panel-body')?.textContent?.trim()).not.toBe('');
                expect(screenControls(container).length).toBeGreaterThan(0);
            });
        });
    }

    // The specific regression: this combination used to pin to Battle, which renders nothing for
    // a corpse, leaving a blank page that every navigation bounced back to.
    it('a dead, still-flagged-ambushed player lands on the death screen with a restart button', () => {
        useGameStore.setState({ player: makePlayer(PLAYER_STATES['dead AND ambushed']) }, false);
        useGameStore.getState().navigate('home');

        expect(useGameStore.getState().screen).toBe('death');
        const { getByRole } = render(<App />);
        expect(getByRole('button', { name: /Play Again/ })).toBeEnabled();
    });

    // Restart is guarded by requireDead, so a living player must always have a route TO death.
    it('a living player can always reach the exit via the suicide screen', () => {
        useGameStore.setState({ player: makePlayer(PLAYER_STATES['alive and well']) }, false);
        useGameStore.getState().navigate('suicide');

        expect(useGameStore.getState().screen).toBe('suicide');
        const { getByRole } = render(<App />);
        expect(getByRole('combobox')).toBeEnabled();
    });
});
