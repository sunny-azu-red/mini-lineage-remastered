import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, fireEvent } from '@testing-library/react';
import { useGameStore } from '@/store/gameStore';
import { makeCatalog, makePlayer } from '../../factories';

// The defaults this file's assertions were written against.
const localPlayer = (o: Partial<Parameters<typeof makePlayer>[0]> = {}) =>
    makePlayer({ started: false, name: null, raceId: null, raceLabel: null, raceEmoji: null, health: null, maxHealth: null, hpPercent: 0, experience: null, level: null, xpCurrent: 0, xpRequired: 0, xpPercent: 0, xpNeeded: 0, adena: null, ...o });

// The defaults this file's assertions were written against.
const localCatalog = (o: Partial<Parameters<typeof makeCatalog>[0]> = {}) =>
    makeCatalog({ nameMinLength: 2, nameMaxLength: 16, races: [ { id: 1, label: 'Human', plural: 'Humans', emoji: '🧑', slug: 'human', enemyRaceId: 2, startHealth: 100, startAdena: 50, ambushChance: 5, regen: 2, crit: 5, backstory: 'Humans are <em>adaptable</em>.', traits: 'Balanced <strong>stats</strong>.', }, { id: 2, label: 'Orc', plural: 'Orcs', emoji: '👹', slug: 'orc', enemyRaceId: 1, startHealth: 120, startAdena: 30, ambushChance: 8, regen: 1, crit: 3, backstory: 'Orcs are brutal.', traits: 'Strong but reckless.', }, ], ...o });

const { requestMock } = vi.hoisted(() => ({ requestMock: vi.fn() }));
vi.mock('@/socket/client', () => ({ request: requestMock }));

const { default: RacesScreen } = await import('@/components/screens/RacesScreen');

function resetStore(overrides: Partial<ReturnType<typeof useGameStore.getState>> = {}) {
    useGameStore.setState(
        {
            status: 'ready',
            player: localPlayer(),
            catalog: localCatalog(),
            screen: 'races',
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

describe('RacesScreen', () => {
    beforeEach(() => {
        requestMock.mockReset();
        // navigate() always calls .then() on this now (to apply the player:screen ack to its
        // own store) — a safe default so tests that don't care about the response don't crash.
        requestMock.mockResolvedValue({ ok: false, error: { code: 'INTERNAL', message: 'mock default' } });
        resetStore();
    });

    it('renders every catalog race with its backstory/traits HTML via Narrative', () => {
        render(<RacesScreen />);

        expect(screen.getByText(/🧑 Human/)).toBeInTheDocument();
        expect(screen.getByText('adaptable')).toBeInTheDocument(); // <em> content, proves raw HTML rendered
        expect(screen.getByText('stats').tagName).toBe('STRONG');

        expect(screen.getByText(/👹 Orc/)).toBeInTheDocument();
        expect(screen.getByText('Orcs are brutal.')).toBeInTheDocument();
        expect(screen.getByText('Strong but reckless.')).toBeInTheDocument();
    });

    it('renders each race as flat h2/p siblings, with no per-race wrapper element', () => {
        const { container } = render(<RacesScreen />);

        // Every direct child of the fragment's parent is an h2 or p — no div/section wrapper
        // was ever inserted per race, matching the old template's flat structure exactly.
        const tagNames = Array.from(container.children).map(el => el.tagName);
        expect(tagNames.every(tag => tag === 'H2' || tag === 'P')).toBe(true);
    });

    it('links back to "start" when no character has been started yet', () => {
        render(<RacesScreen />);
        expect(screen.getByRole('link', { name: /Go back to game start/ })).toBeInTheDocument();
    });

    it('renders nothing while catalog has not loaded', () => {
        useGameStore.setState({ catalog: null }, false);
        const { container } = render(<RacesScreen />);
        expect(container).toBeEmptyDOMElement();
    });

    it('the back link routes an unstarted visitor to the Game Start screen, suppressing the anchor default', () => {
        render(<RacesScreen />);

        const link = screen.getByRole('link', { name: /Go back to game start/ });
        // fireEvent returns false once preventDefault() has been called on the dispatched event.
        expect(fireEvent.click(link)).toBe(false);
        expect(useGameStore.getState().screen).toBe('start');
    });

    it('the back link routes a started player back to Home Town instead', () => {
        resetStore({ player: localPlayer({ started: true, name: 'Hero', raceId: 1 }) });
        render(<RacesScreen />);

        fireEvent.click(screen.getByRole('link', { name: /Go back to game start/ }));

        expect(useGameStore.getState().screen).toBe('home');
    });
});
