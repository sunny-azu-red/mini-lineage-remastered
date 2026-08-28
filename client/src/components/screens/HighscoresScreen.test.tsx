import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import type { GameCatalog, HighscoreList, PlayerSnapshot } from '@shared/contract';
import { useGameStore } from '@/store/gameStore';

const { requestMock } = vi.hoisted(() => ({ requestMock: vi.fn() }));
vi.mock('@/socket/client', () => ({ request: requestMock }));

const { default: HighscoresScreen } = await import('./HighscoresScreen');

function makeCatalog(): GameCatalog {
    return {
        version: '1.5.0', isRelease: false, commitUrl: null, year: 2026, locale: 'en-US',
        lowHealthThreshold: 0.2, maxLevel: 50, nameMinLength: 2, nameMaxLength: 16,
        races: [
            {
                id: 1, label: 'Human', plural: 'Humans', emoji: '🧑', slug: 'human',
                enemyRaceId: 2, startHealth: 100, startAdena: 50, ambushChance: 5, regen: 2, crit: 5,
                backstory: '', traits: '',
            },
            {
                id: 2, label: 'Orc', plural: 'Orcs', emoji: '👹', slug: 'orc',
                enemyRaceId: 1, startHealth: 120, startAdena: 30, ambushChance: 8, regen: 1, crit: 3,
                backstory: '', traits: '',
            },
        ],
        weapons: [], armors: [], foods: [],
    };
}

function makePlayer(overrides: Partial<PlayerSnapshot> = {}): PlayerSnapshot {
    return {
        revision: 1, started: true, name: 'Hero', raceId: 1, raceLabel: 'Human', raceEmoji: '🧑',
        health: 80, maxHealth: 100, hpPercent: 80, lowHealth: false,
        experience: 10, level: 2, isMaxLevel: false, xpCurrent: 10, xpRequired: 100, xpPercent: 10, xpNeeded: 90,
        adena: 500, weapon: null, armor: null, stats: null, effects: [],
        dead: false, ambushed: false, coward: false, cheated: false, deathReason: null, highscoreEligible: false,
        counters: { totalBattles: 0, totalAmbushes: 0, consecutiveAmbushes: 0, totalEnemiesKilled: 0 },
        lastBattle: null,
        ...overrides,
    };
}

function resetStore(overrides: Partial<ReturnType<typeof useGameStore.getState>> = {}) {
    useGameStore.setState(
        {
            status: 'ready',
            player: makePlayer(),
            catalog: makeCatalog(),
            screen: 'highscores',
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

function makeList(overrides: Partial<HighscoreList> = {}): HighscoreList {
    return {
        raceId: null,
        rows: [
            { rank: 1, name: 'Champion', raceId: 1, level: 10, totalXp: 5000, adena: 12000, created: '2026-01-15T10:30:00.000Z' },
            { rank: 2, name: 'A Very Long Name That Should Get Truncated Here', raceId: 2, level: 8, totalXp: 3000, adena: 900, created: '2026-01-10T08:05:00.000Z' },
        ],
        ...overrides,
    };
}

describe('HighscoresScreen', () => {
    beforeEach(() => {
        requestMock.mockReset();
        requestMock.mockResolvedValue({ ok: true, data: makeList() });
        resetStore();
    });

    it('fetches highscores:list on mount with the current filter and renders rows', async () => {
        render(<HighscoresScreen />);

        await waitFor(() => expect(requestMock).toHaveBeenCalledWith('highscores:list', { raceId: null }));
        expect(await screen.findByText(/Champion/)).toBeInTheDocument();
        // Race emoji is prefixed onto the name.
        expect(screen.getByText(/🧑 Champion/)).toBeInTheDocument();
        // Truncated to 20 chars + '...' (matches highscores.view.ts's truncate(name, 20)).
        expect(screen.getByText(/A Very Long Name Tha\.\.\./)).toBeInTheDocument();
    });

    it('re-fetches when the store filter changes and highlights the active tab', async () => {
        render(<HighscoresScreen />);
        await waitFor(() => expect(requestMock).toHaveBeenCalledWith('highscores:list', { raceId: null }));

        requestMock.mockClear();
        requestMock.mockResolvedValue({ ok: true, data: makeList({ raceId: 2 }) });

        fireEvent.click(screen.getByRole('link', { name: /Orc/ }));

        expect(useGameStore.getState().highscoreRaceFilter).toBe(2);
        await waitFor(() => expect(requestMock).toHaveBeenCalledWith('highscores:list', { raceId: 2 }));
    });

    it('clicking "All" clears the filter', async () => {
        resetStore({ highscoreRaceFilter: 1 });
        render(<HighscoresScreen />);
        await waitFor(() => expect(requestMock).toHaveBeenCalledWith('highscores:list', { raceId: 1 }));

        fireEvent.click(screen.getByRole('link', { name: 'All' }));
        expect(useGameStore.getState().highscoreRaceFilter).toBeNull();
    });

    it('shows the empty-hall message when there are no rows', async () => {
        requestMock.mockResolvedValue({ ok: true, data: makeList({ rows: [] }) });
        render(<HighscoresScreen />);

        expect(await screen.findByText(/The halls are silent/)).toBeInTheDocument();
    });
});
