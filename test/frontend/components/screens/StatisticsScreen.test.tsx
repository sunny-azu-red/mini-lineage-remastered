import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import { useGameStore } from '@/store/gameStore';
import { makeCatalog, makePlayer } from '../../factories';

// The defaults this file's assertions were written against.
const localCatalog = (o: Partial<Parameters<typeof makeCatalog>[0]> = {}) =>
    makeCatalog({ nameMinLength: 2, nameMaxLength: 16, ...o });

const { requestMock } = vi.hoisted(() => ({ requestMock: vi.fn() }));
vi.mock('@/socket/client', () => ({ request: requestMock }));

const { default: StatisticsScreen } = await import('@/components/screens/StatisticsScreen');

function resetStore(overrides: Partial<ReturnType<typeof useGameStore.getState>> = {}) {
    useGameStore.setState(
        {
            status: 'ready',
            player: makePlayer(),
            catalog: localCatalog(),
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

    it('the back link routes a started player back to Home Town, suppressing the anchor default', async () => {
        requestMock.mockResolvedValue({ ok: true, data: { stats: null } });
        render(<StatisticsScreen />);
        await screen.findByText(/The ancient archives are empty/);

        const link = screen.getByRole('link', { name: /Go back to game start/ });
        // fireEvent returns false once preventDefault() has been called on the dispatched event.
        expect(fireEvent.click(link)).toBe(false);
        expect(useGameStore.getState().screen).toBe('home');
    });

    it('the back link routes an unstarted visitor to the Game Start screen instead', async () => {
        resetStore({ player: makePlayer({ started: false, name: null, raceId: null }), screen: 'statistics' });
        requestMock.mockResolvedValue({ ok: true, data: { stats: null } });
        render(<StatisticsScreen />);
        await screen.findByText(/The ancient archives are empty/);

        fireEvent.click(screen.getByRole('link', { name: /Go back to game start/ }));

        expect(useGameStore.getState().screen).toBe('start');
    });

    // Regression: a real fetch failure used to collapse into the exact same `stats: null` state
    // as "genuinely no players yet", silently hiding a backend error behind the empty-archives
    // flavor text. It must now surface via the same notice mechanism every other rejected socket
    // action uses.
    it('surfaces a failed statistics:get as a notice, distinct from the genuinely-empty state', async () => {
        requestMock.mockResolvedValue({ ok: false, error: { code: 'INTERNAL', message: '⭕ You got disconnected from the realm, the backend is offline.' } });
        render(<StatisticsScreen />);

        await waitFor(() => expect(useGameStore.getState().notice).toEqual({ code: 'INTERNAL', message: '⭕ You got disconnected from the realm, the backend is offline.' }));
    });

    // Previously this rendered literally nothing while fetching — no prose, no spinner, and no
    // back link, so there was no way off the screen until the request came back.
    it('shows the loader — not the empty-archives message — while the request is in flight', () => {
        requestMock.mockReturnValue(new Promise(() => { /* never settles */ }));
        const { container } = render(<StatisticsScreen />);

        expect(container.querySelector('.loading-spinner')).toBeInTheDocument();
        expect(screen.queryByText(/The ancient archives are empty/)).not.toBeInTheDocument();
    });

    it('keeps the back link reachable while loading', () => {
        requestMock.mockReturnValue(new Promise(() => { /* never settles */ }));
        render(<StatisticsScreen />);

        expect(screen.getByRole('link', { name: /Go back to game start/ })).toBeInTheDocument();
    });
});
