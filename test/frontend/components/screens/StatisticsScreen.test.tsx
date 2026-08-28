import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, waitFor } from '@testing-library/react';
import type { GameCatalog, PlayerSnapshot } from '@shared/contract';
import { useGameStore } from '@/store/gameStore';

const { requestMock } = vi.hoisted(() => ({ requestMock: vi.fn() }));
vi.mock('@/socket/client', () => ({ request: requestMock }));

const { default: StatisticsScreen } = await import('@/components/screens/StatisticsScreen');

function makeCatalog(): GameCatalog {
    return {
        version: '1.5.0', isRelease: false, commitUrl: null, year: 2026, locale: 'en-US',
        lowHealthThreshold: 0.2, maxLevel: 50, nameMinLength: 2, nameMaxLength: 16,
        races: [], weapons: [], armors: [], foods: [],
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
            screen: 'statistics',
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

const RAW_STATS: Record<string, number> = {
    total_players: 1,
    total_levels_gained: 42,
    total_deaths: 5,
    total_players_suicided: 1,
    total_players_cheated: 0,
    total_battles: 120,
    total_enemies_killed: 100,
    total_critical_hits: 15,
    total_xp_gained: 98765,
    total_ambushes: 8,
    total_hp_lost: 4321,
    total_damage_blocked: 2100,
    total_hp_healed: 900,
    total_hp_regen: 300,
    total_adena_generated: 1500000,
    total_adena_spent: 50000,
    total_weapons_bought: 3,
    total_armors_bought: 2,
    total_food_bought: 10,
    total_adena: 200,
};

describe('StatisticsScreen', () => {
    beforeEach(() => {
        requestMock.mockReset();
        resetStore();
    });

    it('shows the empty-archives copy when stats is null', async () => {
        requestMock.mockResolvedValue({ ok: true, data: { stats: null } });
        render(<StatisticsScreen />);

        expect(await screen.findByText(/The ancient archives are empty/)).toBeInTheDocument();
        expect(screen.getByText(/Go back to game start/)).toBeInTheDocument();
    });

    it('renders singular phrasing for a count of exactly 1 (total_players / total_players_suicided)', async () => {
        requestMock.mockResolvedValue({ ok: true, data: { stats: RAW_STATS } });
        render(<StatisticsScreen />);

        // pluralize('Brave Soul', 'Brave Souls', 1) -> "a Brave Soul"
        expect(await screen.findByText(/a Brave Soul/)).toBeInTheDocument();
        expect(screen.getByText(/has set foot upon these dangerous lands/)).toBeInTheDocument();
        // total_players_cheated === 0 -> plural branch, "have" (0 !== 1)
        expect(screen.getByText(/were struck down by the gods/)).toBeInTheDocument();
    });

    it('renders plural phrasing and formatted numbers for counts > 1', async () => {
        requestMock.mockResolvedValue({ ok: true, data: { stats: RAW_STATS } });
        render(<StatisticsScreen />);

        expect(await screen.findByText(/120 Battles/)).toBeInTheDocument();
        expect(screen.getByText(/100 Formidable Foes/)).toBeInTheDocument();
        expect(screen.getByText(/15 Critical Strikes/)).toBeInTheDocument();
        expect(screen.getByText(/98,765 XP/)).toBeInTheDocument();
        expect(screen.getByText(/8 Ambushes/)).toBeInTheDocument();
        // formatAdena(1_500_000) -> '1.5kk'
        expect(screen.getByText(/1\.5kk Adena/)).toBeInTheDocument();
    });

    it('fetches statistics:get exactly once on mount', async () => {
        requestMock.mockResolvedValue({ ok: true, data: { stats: null } });
        render(<StatisticsScreen />);

        await waitFor(() => expect(requestMock).toHaveBeenCalledWith('statistics:get', {}));
        expect(requestMock).toHaveBeenCalledTimes(1);
    });
});
