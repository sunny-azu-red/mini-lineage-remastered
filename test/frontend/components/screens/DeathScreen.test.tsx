import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import type { PlayerSnapshot, HydratePayload } from '@shared/contract';
import { useGameStore } from '@/store/gameStore';

const { requestMock } = vi.hoisted(() => ({ requestMock: vi.fn() }));
vi.mock('@/socket/client', () => ({ request: requestMock }));

const { default: DeathScreen } = await import('@/components/screens/DeathScreen');

function makePlayer(overrides: Partial<PlayerSnapshot> = {}): PlayerSnapshot {
    return {
        revision: 1,
        started: true,
        name: 'Hero',
        raceId: 1,
        raceLabel: 'Human',
        raceEmoji: '🧑',
        health: 0,
        maxHealth: 100,
        hpPercent: 0,
        lowHealth: true,
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
        dead: true,
        ambushed: false,
        coward: false,
        cheated: false,
        deathReason: 'You fought bravely... but not bravely enough.',
        highscoreEligible: true,
        counters: { totalBattles: 0, totalAmbushes: 0, consecutiveAmbushes: 0, totalEnemiesKilled: 0 },
        lastBattle: null,
        ...overrides,
    };
}

function makeCatalog() {
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

function resetStore(overrides: Partial<ReturnType<typeof useGameStore.getState>> = {}) {
    useGameStore.setState(
        {
            status: 'ready',
            player: makePlayer(),
            catalog: makeCatalog(),
            screen: 'death',
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

describe('DeathScreen', () => {
    beforeEach(() => {
        requestMock.mockReset();
        resetStore();
    });

    it('shows the highscore submit button when highscoreEligible', () => {
        resetStore({ player: makePlayer({ highscoreEligible: true, coward: false, cheated: false }) });
        render(<DeathScreen />);
        expect(screen.getByRole('button', { name: /Write your Legacy!/ })).toBeInTheDocument();
    });

    it('hides the highscore submit button for a coward', () => {
        resetStore({ player: makePlayer({ highscoreEligible: false, coward: true, deathReason: '🤡 You took the cowardly way out.' }) });
        render(<DeathScreen />);
        expect(screen.queryByRole('button', { name: /Write your Legacy!/ })).not.toBeInTheDocument();
        // Styled as a danger alert, mirroring death.ejs's `coward` (really "coward-or-cheated") branch.
        expect(screen.getByText(/You took the cowardly way out\./)).toHaveClass('alert', 'alert-danger');
    });

    it('hides the highscore submit button for a cheater even though they are not a coward', () => {
        resetStore({ player: makePlayer({ highscoreEligible: false, coward: false, cheated: true, deathReason: '👾 The gods saw your heresy.' }) });
        render(<DeathScreen />);
        expect(screen.queryByRole('button', { name: /Write your Legacy!/ })).not.toBeInTheDocument();
        expect(screen.getByText(/The gods saw your heresy\./)).toHaveClass('alert', 'alert-danger');
    });

    it('shows a plain paragraph (not a danger alert) for an ordinary, non-coward/non-cheated death', () => {
        resetStore({ player: makePlayer({ highscoreEligible: true, coward: false, cheated: false }) });
        render(<DeathScreen />);
        const reasonEl = screen.getByText(/You fought bravely/);
        expect(reasonEl.tagName).toBe('P');
    });

    it('submitting a highscore calls highscores:submit, re-hydrates, and resolves raceSlug to a raceFilter id', async () => {
        const freshHydrate: HydratePayload = { player: makePlayer({ started: false, dead: false, name: null }), catalog: makeCatalog() };
        requestMock.mockResolvedValue({ ok: true, data: { raceSlug: 'human', hydrate: freshHydrate } });

        render(<DeathScreen />);
        fireEvent.click(screen.getByRole('button', { name: /Write your Legacy!/ }));

        await waitFor(() => expect(requestMock).toHaveBeenCalledWith('highscores:submit', {}));
        await waitFor(() => expect(useGameStore.getState().player).toEqual(freshHydrate.player));
        expect(useGameStore.getState().screen).toBe('highscores');
        // The reconciled behavior: 'human' resolves to raceId 1 via catalog.races (see
        // makeCatalog()), so HighscoresScreen lands pre-filtered to the submitter's own race —
        // not the unfiltered list this used to fall back to before HighscoresScreen existed.
        expect(useGameStore.getState().highscoreRaceFilter).toBe(1);
    });

    it('falls back to no filter (null) if raceSlug does not resolve to any known race', async () => {
        const freshHydrate: HydratePayload = { player: makePlayer({ started: false, dead: false, name: null }), catalog: makeCatalog() };
        requestMock.mockResolvedValue({ ok: true, data: { raceSlug: 'nonexistent-slug', hydrate: freshHydrate } });
        // Seed a stale filter to prove the fallback explicitly clears it rather than leaving it.
        useGameStore.setState({ highscoreRaceFilter: 2 });

        render(<DeathScreen />);
        fireEvent.click(screen.getByRole('button', { name: /Write your Legacy!/ }));

        await waitFor(() => expect(useGameStore.getState().screen).toBe('highscores'));
        expect(useGameStore.getState().highscoreRaceFilter).toBeNull();
    });

    it('restarting calls game:restart and re-hydrates, routing to the actual reset-player shape (a non-null, started:false snapshot)', async () => {
        // Confirms the real server behavior (game.handler.ts's game:restart -> resetPlayer() ->
        // buildPlayerSnapshot()): the ack's hydrate.player is NOT null, it's a real snapshot with
        // `started: false`. gameStore.hydrate() must route this to 'start', not leave the screen
        // stuck on 'death'.
        const freshHydrate: HydratePayload = { player: makePlayer({ started: false, dead: false, name: null, deathReason: null, highscoreEligible: false }), catalog: makeCatalog() };
        requestMock.mockResolvedValue({ ok: true, data: { hydrate: freshHydrate } });

        render(<DeathScreen />);
        fireEvent.click(screen.getByRole('button', { name: /Play Again\?/ }));

        await waitFor(() => expect(requestMock).toHaveBeenCalledWith('game:restart', {}));
        await waitFor(() => expect(useGameStore.getState().screen).toBe('start'));
        expect(useGameStore.getState().player).toEqual(freshHydrate.player);
    });
});
