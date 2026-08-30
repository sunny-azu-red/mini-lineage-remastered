import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import { useGameStore } from '@/store/gameStore';
import { makeCatalog, makePlayer } from '../../factories';

// The defaults this file's assertions were written against.
const localCatalog = (o: Partial<Parameters<typeof makeCatalog>[0]> = {}) =>
    makeCatalog({ nameMinLength: 2, nameMaxLength: 10, races: [ { id: 1, label: 'Human', plural: 'Humans', emoji: '🧙', slug: 'human', enemyRaceId: 2, startHealth: 100, startAdena: 300, ambushChance: 8, regen: 1, crit: 4, backstory: '', traits: '' }, { id: 2, label: 'Orc', plural: 'Orcs', emoji: '🧟', slug: 'orc', enemyRaceId: 1, startHealth: 150, startAdena: 250, ambushChance: 16, regen: 0, crit: 0, backstory: '', traits: '' }, ], ...o });

const { requestMock } = vi.hoisted(() => ({ requestMock: vi.fn() }));
vi.mock('@/socket/client', () => ({ request: requestMock }));

const { default: GameStartScreen } = await import('@/components/screens/GameStartScreen');

function resetStore() {
    useGameStore.setState(
        {
            status: 'ready',
            player: null,
            catalog: localCatalog(),
            screen: 'start',
            highscoreRaceFilter: null,
            flash: null,
            lastBattle: null,
            notice: null,
            soundEnabled: false,
        },
        false,
    );
}

// The ack `game:start` really returns: a full, STARTED snapshot. It must carry `started: true`,
// because pinScreen keeps a player with no character off Home.
const startedPlayer = makePlayer({ name: 'Aria', started: true, dead: false, ambushed: false });

describe('GameStartScreen', () => {
    beforeEach(() => {
        requestMock.mockReset();
        resetStore();
    });

    it('submits with the correct payload (trimmed name + selected race)', async () => {
        requestMock.mockResolvedValue({ ok: true, data: { player: startedPlayer, flash: null } });
        render(<GameStartScreen />);

        fireEvent.change(screen.getByPlaceholderText('Enter your name, Heir'), { target: { value: '  Aria  ' } });
        fireEvent.change(screen.getByRole('combobox'), { target: { value: '2' } });
        fireEvent.click(screen.getByRole('button', { name: '🚩 Start' }));

        await waitFor(() => expect(requestMock).toHaveBeenCalled());
        expect(requestMock).toHaveBeenCalledWith('game:start', { raceId: 2, name: 'Aria' });
    });

    it('navigates home on success', async () => {
        requestMock.mockResolvedValue({ ok: true, data: { player: startedPlayer, flash: null } });
        render(<GameStartScreen />);

        fireEvent.change(screen.getByPlaceholderText('Enter your name, Heir'), { target: { value: 'Aria' } });
        fireEvent.click(screen.getByRole('button', { name: '🚩 Start' }));

        await waitFor(() => expect(useGameStore.getState().screen).toBe('home'));
        expect(useGameStore.getState().player).toEqual(startedPlayer);
    });

    it('shows a client-side validation message for an out-of-range name length before calling the server', () => {
        render(<GameStartScreen />);

        fireEvent.change(screen.getByPlaceholderText('Enter your name, Heir'), { target: { value: 'A' } });
        fireEvent.click(screen.getByRole('button', { name: '🚩 Start' }));

        expect(requestMock).not.toHaveBeenCalled();
        expect(screen.getByText(/must be between 2 and 10 characters/i)).toBeInTheDocument();
    });

    it('falls back to raceId 0 when the catalog somehow carries no races at all', async () => {
        useGameStore.setState({ catalog: { ...makeCatalog(), races: [] } }, false);
        requestMock.mockResolvedValue({ ok: true, data: { player: startedPlayer, flash: null } });
        render(<GameStartScreen />);

        fireEvent.change(screen.getByPlaceholderText('Enter your name, Heir'), { target: { value: 'Aria' } });
        fireEvent.click(screen.getByRole('button', { name: '🚩 Start' }));

        await waitFor(() => expect(requestMock).toHaveBeenCalledWith('game:start', { raceId: 0, name: 'Aria' }));
    });

    it('renders nothing until the catalog arrives (the race <select> and name limits both need it)', () => {
        useGameStore.setState({ catalog: null }, false);
        const { container } = render(<GameStartScreen />);

        expect(container).toBeEmptyDOMElement();
    });

    it.each([
        ['Hall of Champions', 'highscores'],
        ['The Tome of Lore', 'statistics'],
        ['Chronicles of Ancestry', 'races'],
    ] as const)('the "%s" link navigates to the "%s" screen instead of following the anchor', (linkName, target) => {
        // navigate() calls .then() on this (to apply the player:screen ack to its own store).
        requestMock.mockResolvedValue({ ok: false, error: { code: 'INTERNAL', message: 'mock default' } });
        render(<GameStartScreen />);

        const link = screen.getByRole('link', { name: linkName });
        // fireEvent returns false once preventDefault() has been called on the dispatched event.
        expect(fireEvent.click(link)).toBe(false);
        expect(useGameStore.getState().screen).toBe(target);
    });
});
