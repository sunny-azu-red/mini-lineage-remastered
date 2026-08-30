import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import { useGameStore } from '@/store/gameStore';
import { makeCatalog, makePlayer } from '../../factories';

// The defaults this file's assertions were written against.
const localCatalog = (o: Partial<Parameters<typeof makeCatalog>[0]> = {}) =>
    makeCatalog({ foods: [ { id: 1, name: 'Bread', emoji: '🍞', stat: 20, cost: 50 }, ], ...o });

const { requestMock } = vi.hoisted(() => ({ requestMock: vi.fn() }));
vi.mock('@/socket/client', () => ({ request: requestMock }));

const { default: InnScreen } = await import('@/components/screens/InnScreen');

function resetStore() {
    useGameStore.setState(
        {
            status: 'ready',
            player: makePlayer(),
            catalog: localCatalog(),
            screen: 'inn',
            highscoreRaceFilter: null,
            flash: null,
            lastBattle: null,
            notice: null,
            soundEnabled: false,
        },
        false,
    );
}

describe('InnScreen', () => {
    beforeEach(() => {
        requestMock.mockReset();
        // navigate() always calls .then() on this now (to apply the player:screen ack to its
        // own store) — a safe default so tests that don't care about the response don't crash;
        // individual tests below still override it with their own mockResolvedValue.
        requestMock.mockResolvedValue({ ok: false, error: { code: 'INTERNAL', message: 'mock default' } });
        resetStore();
    });

    it('exposes a tooltip on every abbreviated stat column header', () => {
        render(<InnScreen />);

        expect(screen.getByRole('columnheader', { name: 'Max HP+' })).toHaveAttribute('title', 'Maximum Health Point Increase');
        expect(screen.getByRole('columnheader', { name: 'HP Heal' })).toHaveAttribute('title', 'Health Point Heal');
    });

    it('submitting with nothing selected (the placeholder) navigates home without calling the server', async () => {
        render(<InnScreen />);

        fireEvent.click(screen.getByRole('button', { name: 'Return' }));

        await waitFor(() => expect(useGameStore.getState().screen).toBe('home'));
        expect(requestMock).not.toHaveBeenCalledWith('shop:purchase', expect.anything());
    });

    it('a real selection still purchases', async () => {
        const newPlayer = makePlayer({ adena: 450 });
        requestMock.mockResolvedValue({ ok: true, data: { player: newPlayer, flash: { text: 'Ate!', type: 'success' } } });

        render(<InnScreen />);

        fireEvent.change(screen.getByRole('combobox'), { target: { value: '1' } });
        fireEvent.click(screen.getByRole('button', { name: '🪙 Order' }));

        await waitFor(() => expect(requestMock).toHaveBeenCalledWith('shop:purchase', { type: 'food', itemId: 1 }));
        await waitFor(() => expect(useGameStore.getState().player).toEqual(newPlayer));

        expect(useGameStore.getState().flash).toEqual({ text: 'Ate!', type: 'success' });
        expect(useGameStore.getState().screen).toBe('inn');
    });

    it('shows a food\'s Max HP+ bonus when it has one, and a muted dash when it does not', () => {
        const catalog = localCatalog();
        useGameStore.setState(
            {
                catalog: {
                    ...catalog,
                    foods: [
                        { id: 1, name: 'Bread', emoji: '🍞', stat: 20, cost: 50 },
                        { id: 2, name: 'Hearty Stew', emoji: '🍲', stat: 40, cost: 120, maxHealth: 5 },
                    ],
                },
            },
            false,
        );
        const { container } = render(<InnScreen />);

        expect(container.querySelector('.hp')?.textContent).toBe('+5');
        expect(container.querySelector('.muted')?.textContent).toBe('-');
    });

    it('renders nothing until the catalog arrives (the item list comes straight from it)', () => {
        useGameStore.setState({ catalog: null }, false);
        const { container } = render(<InnScreen />);

        expect(container).toBeEmptyDOMElement();
    });
});
