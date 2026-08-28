import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import type { GameCatalog } from '@shared/contract';
import { useGameStore } from '@/store/gameStore';

const { requestMock } = vi.hoisted(() => ({ requestMock: vi.fn() }));
vi.mock('@/socket/client', () => ({ request: requestMock }));

const { default: GameStartScreen } = await import('./GameStartScreen');

function makeCatalog(): GameCatalog {
    return {
        version: '1.5.0',
        isRelease: false,
        commitUrl: null,
        year: 2026,
        locale: 'en-US',
        lowHealthThreshold: 0.2,
        maxLevel: 50,
        nameMinLength: 2,
        nameMaxLength: 10,
        races: [
            { id: 1, label: 'Human', plural: 'Humans', emoji: '🧙', slug: 'human', enemyRaceId: 2, startHealth: 100, startAdena: 300, ambushChance: 8, regen: 1, crit: 4, backstory: '', traits: '' },
            { id: 2, label: 'Orc', plural: 'Orcs', emoji: '🧟', slug: 'orc', enemyRaceId: 1, startHealth: 150, startAdena: 250, ambushChance: 16, regen: 0, crit: 0, backstory: '', traits: '' },
        ],
        weapons: [],
        armors: [],
        foods: [],
    };
}

function resetStore() {
    useGameStore.setState(
        {
            status: 'ready',
            player: null,
            catalog: makeCatalog(),
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

describe('GameStartScreen', () => {
    beforeEach(() => {
        requestMock.mockReset();
        resetStore();
    });

    it('submits with the correct payload (trimmed name + selected race)', async () => {
        requestMock.mockResolvedValue({ ok: true, data: { player: { name: 'Aria' } as any, flash: null } });
        render(<GameStartScreen />);

        fireEvent.change(screen.getByPlaceholderText('Enter your name, Heir'), { target: { value: '  Aria  ' } });
        fireEvent.change(screen.getByRole('combobox'), { target: { value: '2' } });
        fireEvent.click(screen.getByRole('button', { name: '🚩 Start' }));

        await waitFor(() => expect(requestMock).toHaveBeenCalled());
        expect(requestMock).toHaveBeenCalledWith('game:start', { raceId: 2, name: 'Aria' });
    });

    it('navigates home on success', async () => {
        requestMock.mockResolvedValue({ ok: true, data: { player: { name: 'Aria' } as any, flash: null } });
        render(<GameStartScreen />);

        fireEvent.change(screen.getByPlaceholderText('Enter your name, Heir'), { target: { value: 'Aria' } });
        fireEvent.click(screen.getByRole('button', { name: '🚩 Start' }));

        await waitFor(() => expect(useGameStore.getState().screen).toBe('home'));
        expect(useGameStore.getState().player).toEqual({ name: 'Aria' });
    });

    it('shows a client-side validation message for an out-of-range name length before calling the server', () => {
        render(<GameStartScreen />);

        fireEvent.change(screen.getByPlaceholderText('Enter your name, Heir'), { target: { value: 'A' } });
        fireEvent.click(screen.getByRole('button', { name: '🚩 Start' }));

        expect(requestMock).not.toHaveBeenCalled();
        expect(screen.getByText(/must be between 2 and 10 characters/i)).toBeInTheDocument();
    });
});
