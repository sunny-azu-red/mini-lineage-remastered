import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import type { PlayerSnapshot } from '@shared/contract';
import { useGameStore } from '@/store/gameStore';

const { requestMock } = vi.hoisted(() => ({ requestMock: vi.fn() }));
vi.mock('@/socket/client', () => ({ request: requestMock }));

const { playSoundMock } = vi.hoisted(() => ({ playSoundMock: vi.fn() }));
vi.mock('@/audio/soundfx', () => ({ playSound: playSoundMock }));

const { default: SuicideScreen } = await import('@/components/screens/SuicideScreen');

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
            catalog: null,
            screen: 'suicide',
            highscoreRaceFilter: null,
            flash: null,
            lastBattle: null,
            notice: null,
            soundEnabled: false,
        },
        false,
    );
}

describe('SuicideScreen', () => {
    beforeEach(() => {
        requestMock.mockReset();
        playSoundMock.mockReset();
        resetStore();
    });

    it('loads with "No, I changed my mind" pre-selected and an immediately-clickable Return button, no placeholder option', () => {
        render(<SuicideScreen />);

        const select = screen.getByRole('combobox') as HTMLSelectElement;
        expect(select.value).toBe('no');
        expect(screen.queryByText('What will you do?')).not.toBeInTheDocument();

        const button = screen.getByRole('button', { name: 'Phew 😅' });
        expect(button).not.toBeDisabled();
    });

    it('confirming calls player:suicide, applies the mutation, navigates to death, and plays the death sound', async () => {
        const deadPlayer = makePlayer({ dead: true, deathReason: 'You took the cowardly way out.', coward: true });
        requestMock.mockResolvedValue({ ok: true, data: { player: deadPlayer, flash: null } });

        render(<SuicideScreen />);

        fireEvent.change(screen.getByRole('combobox'), { target: { value: 'yes' } });
        fireEvent.click(screen.getByRole('button', { name: 'Do it 🥀' }));

        await waitFor(() => expect(requestMock).toHaveBeenCalledWith('player:suicide', {}));
        await waitFor(() => expect(useGameStore.getState().screen).toBe('death'));

        expect(useGameStore.getState().player).toEqual(deadPlayer);
        expect(playSoundMock).toHaveBeenCalledWith('death');
    });

    it('cancelling navigates home without calling the server', () => {
        render(<SuicideScreen />);

        fireEvent.change(screen.getByRole('combobox'), { target: { value: 'no' } });
        fireEvent.click(screen.getByRole('button', { name: 'Phew 😅' }));

        expect(requestMock).not.toHaveBeenCalled();
        expect(playSoundMock).not.toHaveBeenCalled();
        expect(useGameStore.getState().screen).toBe('home');
    });
});
