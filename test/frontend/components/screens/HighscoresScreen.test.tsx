import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import type { HighscoreList } from '@shared/contract';
import { useGameStore } from '@/store/gameStore';
import { makeCatalog, makePlayer } from '../../factories';

// The defaults this file's assertions were written against.
const localCatalog = (o: Partial<Parameters<typeof makeCatalog>[0]> = {}) =>
    makeCatalog({ nameMinLength: 2, nameMaxLength: 16, races: [ { id: 1, label: 'Human', plural: 'Humans', emoji: '🧑', slug: 'human', enemyRaceId: 2, startHealth: 100, startAdena: 50, ambushChance: 5, regen: 2, crit: 5, backstory: '', traits: '', }, { id: 2, label: 'Orc', plural: 'Orcs', emoji: '👹', slug: 'orc', enemyRaceId: 1, startHealth: 120, startAdena: 30, ambushChance: 8, regen: 1, crit: 3, backstory: '', traits: '', }, ], ...o });

const { requestMock } = vi.hoisted(() => ({ requestMock: vi.fn() }));
vi.mock('@/socket/client', () => ({ request: requestMock }));

const { default: HighscoresScreen } = await import('@/components/screens/HighscoresScreen');

function resetStore(overrides: Partial<ReturnType<typeof useGameStore.getState>> = {}) {
    useGameStore.setState(
        {
            status: 'ready',
            player: makePlayer(),
            catalog: localCatalog(),
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
            { name: 'Champion', raceId: 1, level: 10, totalXp: 5000, adena: 12000, created: '2026-01-15T10:30:00.000Z' },
            { name: 'A Very Long Name That Should Get Truncated Here', raceId: 2, level: 8, totalXp: 3000, adena: 900, created: '2026-01-10T08:05:00.000Z' },
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

    it('does not render a Rank column — the original game never had one', async () => {
        render(<HighscoresScreen />);

        await screen.findByText(/Champion/);
        expect(screen.queryByRole('columnheader', { name: 'Rank' })).not.toBeInTheDocument();
    });

    it('puts the column classes directly on the cell, not on a nested span', async () => {
        const { container } = render(<HighscoresScreen />);
        await screen.findByText(/Champion/);

        expect(container.querySelector('th.center')?.textContent).toBe('Level');
        expect(container.querySelector('td.center')?.textContent).toBe('10');
        expect(container.querySelector('td.xp')?.textContent).toBe('5,000');
        expect(container.querySelector('td.gold')?.textContent).toBe('🪙 12k');
        expect(container.querySelector('td.muted')).not.toBeNull();
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

    it('falls back to a "❓" emoji for a row whose raceId is not in the catalog', async () => {
        requestMock.mockResolvedValue({
            ok: true,
            data: makeList({
                rows: [{ name: 'Ghost', raceId: 99, level: 3, totalXp: 100, adena: 5, created: '2026-02-01T00:00:00.000Z' }],
            }),
        });
        render(<HighscoresScreen />);

        expect(await screen.findByText(/❓ Ghost/)).toBeInTheDocument();
    });

    it('renders nothing while catalog has not loaded (race filter buttons need it)', () => {
        resetStore({ catalog: null });
        const { container } = render(<HighscoresScreen />);

        expect(container).toBeEmptyDOMElement();
    });

    it('the back link continues a started player\'s journey at Home Town, suppressing the anchor default', async () => {
        render(<HighscoresScreen />);
        await screen.findByText(/Champion/);

        const link = screen.getByRole('link', { name: 'Continue your journey' });
        // fireEvent returns false once preventDefault() has been called on the dispatched event.
        expect(fireEvent.click(link)).toBe(false);
        expect(useGameStore.getState().screen).toBe('home');
    });

    it('the back link routes an unstarted visitor to the Game Start screen, with the matching copy', async () => {
        resetStore({ player: makePlayer({ started: false, name: null, raceId: null }) });
        render(<HighscoresScreen />);
        await screen.findByText(/Champion/);

        fireEvent.click(screen.getByRole('link', { name: 'Go back to game start' }));

        expect(useGameStore.getState().screen).toBe('start');
    });

    // The reported symptom: the Hall of Champions announced itself empty while the request was
    // still on the wire, then filled in. "No soul has yet earned a place" is a factual claim, and
    // it must never be made before an answer has actually come back.
    it('shows the loader — not the empty-hall message — while the request is in flight', () => {
        requestMock.mockReturnValue(new Promise(() => { /* never settles */ }));
        const { container } = render(<HighscoresScreen />);

        expect(container.querySelector('.loading-spinner')).toBeInTheDocument();
        expect(screen.queryByText(/The halls are silent/)).not.toBeInTheDocument();
    });

    it('keeps the race filter and back link usable while loading', () => {
        requestMock.mockReturnValue(new Promise(() => { /* never settles */ }));
        render(<HighscoresScreen />);

        expect(screen.getByRole('link', { name: 'All' })).toBeInTheDocument();
        expect(screen.getByRole('link', { name: /Go back|Continue your journey/ })).toBeInTheDocument();
    });

    it('keeps the previous table on screen while switching race tabs', async () => {
        render(<HighscoresScreen />);
        await screen.findByText(/Champion/);

        // A re-fetch that has not come back yet must not blank the table or claim it is empty.
        requestMock.mockReturnValue(new Promise(() => { /* never settles */ }));
        fireEvent.click(screen.getByRole('link', { name: /Orc/ }));

        expect(screen.getByText(/Champion/)).toBeInTheDocument();
        expect(screen.queryByText(/The halls are silent/)).not.toBeInTheDocument();
    });

    // Previously this failure was swallowed entirely: a backend outage rendered as "the
    // leaderboard is empty", with no banner and no way to tell the difference.
    it('surfaces a failed fetch as a notice instead of a silent empty hall', async () => {
        const error = { code: 'INTERNAL' as const, message: '⭕ backend is offline.' };
        requestMock.mockResolvedValue({ ok: false, error });

        render(<HighscoresScreen />);

        await waitFor(() => expect(useGameStore.getState().notice).toEqual(error));
    });
});
