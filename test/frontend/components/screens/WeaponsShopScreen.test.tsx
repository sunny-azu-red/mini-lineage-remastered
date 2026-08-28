import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import type { GameCatalog, PlayerSnapshot } from '@shared/contract';
import { useGameStore } from '@/store/gameStore';

const { requestMock } = vi.hoisted(() => ({ requestMock: vi.fn() }));
vi.mock('@/socket/client', () => ({ request: requestMock }));

const { default: WeaponsShopScreen } = await import('@/components/screens/WeaponsShopScreen');

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
        races: [],
        weapons: [
            { id: 0, name: `Brawler's Fists`, emoji: '👊', stat: 7, cost: 0 },
            { id: 1, name: 'Elven Needle', emoji: '🗡️', stat: 16, cost: 300 },
            { id: 2, name: 'Stormbringer', emoji: '⚡', stat: 28, cost: 5000 },
        ],
        armors: [],
        foods: [],
    };
}

function makePlayer(overrides: Partial<PlayerSnapshot> = {}): PlayerSnapshot {
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
        weapon: { id: 1, name: 'Elven Needle', emoji: '🗡️', stat: 16, cost: 300 },
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
        ...overrides,
    };
}

function resetStore(player: PlayerSnapshot) {
    useGameStore.setState(
        {
            status: 'ready',
            player,
            catalog: makeCatalog(),
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
        resetStore(makePlayer());
    });

    it('carries the same column header tooltips as the original weapons-shop.ejs', () => {
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
        const newPlayer = makePlayer({ weapon: { id: 2, name: 'Stormbringer', emoji: '⚡', stat: 28, cost: 5000 }, adena: 200 });
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
        // purchase; the SPA must reproduce it explicitly (key={player.revision}) so the button
        // can't be spammed to buy the same item repeatedly.
        const newPlayer = makePlayer({
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

    it('submitting with nothing selected (the placeholder) navigates home without calling the server', async () => {
        render(<WeaponsShopScreen />);

        fireEvent.click(screen.getByRole('button', { name: 'Return' }));

        await waitFor(() => expect(useGameStore.getState().screen).toBe('home'));
        expect(requestMock).not.toHaveBeenCalledWith('shop:purchase', expect.anything());
    });
});
