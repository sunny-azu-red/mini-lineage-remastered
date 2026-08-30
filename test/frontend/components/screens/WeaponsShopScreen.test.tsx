import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, fireEvent, waitFor, act } from '@testing-library/react';
import type { PlayerSnapshot } from '@shared/contract';
import { useGameStore } from '@/store/gameStore';
import { makeCatalog, makePlayer } from '../../factories';

// The defaults this file's assertions were written against.
const localPlayer = (o: Partial<Parameters<typeof makePlayer>[0]> = {}) =>
    makePlayer({ weapon: { id: 1, name: 'Elven Needle', emoji: '🗡️', stat: 16, cost: 300 }, ...o });

// The defaults this file's assertions were written against.
const localCatalog = (o: Partial<Parameters<typeof makeCatalog>[0]> = {}) =>
    makeCatalog({ weapons: [ { id: 0, name: `Brawler's Fists`, emoji: '👊', stat: 7, cost: 0 }, { id: 1, name: 'Elven Needle', emoji: '🗡️', stat: 16, cost: 300 }, { id: 2, name: 'Stormbringer', emoji: '⚡', stat: 28, cost: 5000 }, ], ...o });

const { requestMock } = vi.hoisted(() => ({ requestMock: vi.fn() }));
vi.mock('@/socket/client', () => ({ request: requestMock }));

const { default: WeaponsShopScreen } = await import('@/components/screens/WeaponsShopScreen');

function resetStore(player: PlayerSnapshot) {
    useGameStore.setState(
        {
            status: 'ready',
            player,
            catalog: localCatalog(),
            screen: 'weapons',
            highscoreRaceFilter: null,
            flash: null,
            lastBattle: null,
            notice: null,
            soundEnabled: false,
        },
        false,
    );
}

describe('WeaponsShopScreen', () => {
    beforeEach(() => {
        requestMock.mockReset();
        // navigate() always calls .then() on this now (to apply the player:screen ack to its
        // own store) — a safe default so tests that don't care about the response don't crash;
        // individual tests below still override it with their own mockResolvedValue.
        requestMock.mockResolvedValue({ ok: false, error: { code: 'INTERNAL', message: 'mock default' } });
        resetStore(localPlayer());
    });

    it('exposes a tooltip on every abbreviated stat column header', () => {
        render(<WeaponsShopScreen />);

        expect(screen.getByRole('columnheader', { name: 'C. Hit %' })).toHaveAttribute('title', 'Critical Hit Chance');
        expect(screen.getByRole('columnheader', { name: 'P. Attack' })).toHaveAttribute('title', 'Physical Attack');
    });

    it('excludes the starting weapon and disables/marks the currently-equipped item', () => {
        render(<WeaponsShopScreen />);

        // Starting item (id 0, Brawler's Fists) is never purchasable/listed.
        expect(screen.queryByText(/Brawler's Fists/)).not.toBeInTheDocument();

        const owned = screen.getByRole('option', { name: /Elven Needle.*\(Owned\)/ }) as HTMLOptionElement;
        expect(owned.disabled).toBe(true);

        const notOwned = screen.getByRole('option', { name: 'Pick ⚡ Stormbringer' }) as HTMLOptionElement;
        expect(notOwned.disabled).toBe(false);
    });

    it('purchasing successfully calls applyMutation and stays on the weapons screen', async () => {
        const newPlayer = localPlayer({ weapon: { id: 2, name: 'Stormbringer', emoji: '⚡', stat: 28, cost: 5000 }, adena: 200 });
        requestMock.mockResolvedValue({ ok: true, data: { player: newPlayer, flash: { text: 'Bought!', type: 'success' } } });

        render(<WeaponsShopScreen />);

        fireEvent.change(screen.getByRole('combobox'), { target: { value: '2' } });
        fireEvent.click(screen.getByRole('button', { name: '🪙 Purchase' }));

        await waitFor(() => expect(requestMock).toHaveBeenCalledWith('shop:purchase', { type: 'weapon', itemId: 2 }));
        await waitFor(() => expect(useGameStore.getState().player).toEqual(newPlayer));

        expect(useGameStore.getState().flash).toEqual({ text: 'Bought!', type: 'success' });
        expect(useGameStore.getState().screen).toBe('weapons');
    });

    it('resets the select back to its default placeholder after a successful purchase, instead of leaving the just-bought item selected', async () => {
        // Regression test: the old app reset this for free via a full page reload after every
        // purchase; the SPA must reproduce it explicitly (a local purchase-epoch counter,
        // remounting SelectActionForm) so the button can't be spammed to buy the same item
        // repeatedly.
        const newPlayer = localPlayer({
            revision: 2, // a real mutation always bumps this
            weapon: { id: 2, name: 'Stormbringer', emoji: '⚡', stat: 28, cost: 5000 },
            adena: 200,
        });
        requestMock.mockResolvedValue({ ok: true, data: { player: newPlayer, flash: { text: 'Bought!', type: 'success' } } });

        render(<WeaponsShopScreen />);

        fireEvent.change(screen.getByRole('combobox'), { target: { value: '2' } });
        expect(screen.getByRole('button', { name: '🪙 Purchase' })).toBeInTheDocument();

        fireEvent.click(screen.getByRole('button', { name: '🪙 Purchase' }));
        await waitFor(() => expect(useGameStore.getState().player?.revision).toBe(2));

        // The form remounted: back to the default "Return" button and an unselected combobox,
        // not stuck showing "Purchase" with Stormbringer still picked.
        expect(screen.getByRole('button', { name: 'Return' })).toBeInTheDocument();
        expect(screen.queryByRole('button', { name: '🪙 Purchase' })).not.toBeInTheDocument();
        expect((screen.getByRole('combobox') as HTMLSelectElement).value).toBe('');
    });

    // Regression: this form used to key off player?.revision directly, which bumps on ANY
    // persisted mutation for the session — including a routine regen tick, an aura sync, or
    // another tab's action — not just a purchase from THIS form. That meant an open selection
    // (e.g. picking Stormbringer, not yet clicking Purchase) got silently discarded the moment a
    // background tick happened to heal HP, closing the select and reverting the button back to
    // "Return" out from under the player mid-decision.
    it('does not reset the selection when an unrelated background update bumps revision (e.g. a regen tick)', () => {
        render(<WeaponsShopScreen />);

        fireEvent.change(screen.getByRole('combobox'), { target: { value: '2' } });
        expect(screen.getByRole('button', { name: '🪙 Purchase' })).toBeInTheDocument();

        // Simulates a state:update push from an unrelated periodic regen tick — same shape
        // applyUpdate() receives from the socket, bumping revision with nothing to do with this
        // form's own purchase flow.
        act(() => {
            useGameStore.getState().applyUpdate({ revision: 2, health: 81 });
        });

        expect(screen.getByRole('button', { name: '🪙 Purchase' })).toBeInTheDocument();
        expect((screen.getByRole('combobox') as HTMLSelectElement).value).toBe('2');
    });

    it('submitting with nothing selected (the placeholder) navigates home without calling the server', async () => {
        render(<WeaponsShopScreen />);

        fireEvent.click(screen.getByRole('button', { name: 'Return' }));

        await waitFor(() => expect(useGameStore.getState().screen).toBe('home'));
        expect(requestMock).not.toHaveBeenCalledWith('shop:purchase', expect.anything());
    });

    it('shows a weapon\'s critical-hit chance when it has one, and a muted dash when it does not', () => {
        const catalog = localCatalog();
        useGameStore.setState(
            {
                catalog: {
                    ...catalog,
                    weapons: [
                        { id: 0, name: `Brawler's Fists`, emoji: '👊', stat: 7, cost: 0 },
                        { id: 1, name: 'Elven Needle', emoji: '🗡️', stat: 16, cost: 300 },
                        { id: 2, name: 'Stormbringer', emoji: '⚡', stat: 28, cost: 5000, crit: 7 },
                    ],
                },
            },
            false,
        );
        const { container } = render(<WeaponsShopScreen />);

        expect(container.querySelector('.crit')?.textContent).toBe('7%');
        expect(container.querySelector('.muted')?.textContent).toBe('-');
    });

    it('renders nothing until the catalog arrives (the item list comes straight from it)', () => {
        useGameStore.setState({ catalog: null }, false);
        const { container } = render(<WeaponsShopScreen />);

        expect(container).toBeEmptyDOMElement();
    });
});
