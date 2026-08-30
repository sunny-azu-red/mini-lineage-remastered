import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import { useGameStore } from '@/store/gameStore';
import { makeCatalog, makePlayer } from '../../factories';

// The defaults this file's assertions were written against.
const localCatalog = (o: Partial<Parameters<typeof makeCatalog>[0]> = {}) =>
    makeCatalog({ armors: [ { id: 0, name: `Peasant's Tunic`, emoji: '🥋', stat: 2, cost: 0 }, { id: 1, name: 'Chainmail', emoji: '🛡️', stat: 12, cost: 400 }, ], ...o });

const { requestMock } = vi.hoisted(() => ({ requestMock: vi.fn() }));
vi.mock('@/socket/client', () => ({ request: requestMock }));

const { default: ArmorsShopScreen } = await import('@/components/screens/ArmorsShopScreen');

function resetStore() {
    useGameStore.setState(
        {
            status: 'ready',
            player: makePlayer(),
            catalog: localCatalog(),
            screen: 'armors',
            highscoreRaceFilter: null,
            flash: null,
            lastBattle: null,
            notice: null,
            soundEnabled: false,
        },
        false,
    );
}

describe('ArmorsShopScreen', () => {
    beforeEach(() => {
        requestMock.mockReset();
        // navigate() always calls .then() on this now (to apply the player:screen ack to its
        // own store) — a safe default so tests that don't care about the response don't crash;
        // individual tests below still override it with their own mockResolvedValue.
        requestMock.mockResolvedValue({ ok: false, error: { code: 'INTERNAL', message: 'mock default' } });
        resetStore();
    });

    it('exposes a tooltip on every abbreviated stat column header', () => {
        render(<ArmorsShopScreen />);

        expect(screen.getByRole('columnheader', { name: 'HP Regen' })).toHaveAttribute('title', 'Health Point Regeneration');
        expect(screen.getByRole('columnheader', { name: 'P. Defense' })).toHaveAttribute('title', 'Physical Defense');
    });

    it('submitting with nothing selected (the placeholder) navigates home without calling the server', async () => {
        render(<ArmorsShopScreen />);

        fireEvent.click(screen.getByRole('button', { name: 'Return' }));

        await waitFor(() => expect(useGameStore.getState().screen).toBe('home'));
        expect(requestMock).not.toHaveBeenCalledWith('shop:purchase', expect.anything());
    });

    it('a real selection still purchases', async () => {
        const newPlayer = makePlayer({ armor: { id: 1, name: 'Chainmail', emoji: '🛡️', stat: 12, cost: 400 }, adena: 100 });
        requestMock.mockResolvedValue({ ok: true, data: { player: newPlayer, flash: { text: 'Bought!', type: 'success' } } });

        render(<ArmorsShopScreen />);

        fireEvent.change(screen.getByRole('combobox'), { target: { value: '1' } });
        fireEvent.click(screen.getByRole('button', { name: '🪙 Purchase' }));

        await waitFor(() => expect(requestMock).toHaveBeenCalledWith('shop:purchase', { type: 'armor', itemId: 1 }));
        await waitFor(() => expect(useGameStore.getState().player).toEqual(newPlayer));

        expect(useGameStore.getState().flash).toEqual({ text: 'Bought!', type: 'success' });
        expect(useGameStore.getState().screen).toBe('armors');
    });

    it('shows an armor\'s HP Regen bonus when it has one, and a muted dash when it does not', () => {
        const catalog = localCatalog();
        useGameStore.setState(
            {
                catalog: {
                    ...catalog,
                    armors: [
                        { id: 0, name: `Peasant's Tunic`, emoji: '🥋', stat: 2, cost: 0 },
                        { id: 1, name: 'Chainmail', emoji: '🛡️', stat: 12, cost: 400 },
                        { id: 2, name: 'Blessed Plate', emoji: '✨', stat: 30, cost: 5000, regen: 4 },
                    ],
                },
            },
            false,
        );
        const { container } = render(<ArmorsShopScreen />);

        expect(container.querySelector('.heal')?.textContent).toBe('+4');
        expect(container.querySelector('.muted')?.textContent).toBe('-');
    });

    it('renders nothing until the catalog arrives (the item list comes straight from it)', () => {
        useGameStore.setState({ catalog: null }, false);
        const { container } = render(<ArmorsShopScreen />);

        expect(container).toBeEmptyDOMElement();
    });
});
