import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import type { GameCatalog, PlayerSnapshot } from '@shared/contract';
import { useGameStore } from '@/store/gameStore';

const { requestMock } = vi.hoisted(() => ({ requestMock: vi.fn() }));
vi.mock('@/socket/client', () => ({ request: requestMock }));

const { default: ArmorsShopScreen } = await import('./ArmorsShopScreen');

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
        weapons: [],
        armors: [
            { id: 0, name: `Peasant's Tunic`, emoji: '🥋', stat: 2, cost: 0 },
            { id: 1, name: 'Chainmail', emoji: '🛡️', stat: 12, cost: 400 },
        ],
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
        ...overrides,
    };
}

function resetStore() {
    useGameStore.setState(
        {
            status: 'ready',
            player: makePlayer(),
            catalog: makeCatalog(),
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
        resetStore();
    });

    it('submitting with nothing selected (the placeholder) navigates home without calling the server', async () => {
        render(<ArmorsShopScreen />);

        fireEvent.click(screen.getByRole('button', { name: 'Return' }));

        await waitFor(() => expect(useGameStore.getState().screen).toBe('home'));
        expect(requestMock).not.toHaveBeenCalled();
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
});
