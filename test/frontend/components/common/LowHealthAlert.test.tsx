import { describe, it, expect, beforeEach } from 'vitest';
import { render, screen, fireEvent } from '@testing-library/react';
import type { PlayerSnapshot } from '@shared/contract';
import { useGameStore, type ScreenId } from '@/store/gameStore';
import LowHealthAlert from '@/components/common/LowHealthAlert';

function makePlayer(overrides: Partial<PlayerSnapshot> = {}): PlayerSnapshot {
    return {
        revision: 1,
        started: true,
        name: 'Hero',
        raceId: 1,
        raceLabel: 'Human',
        raceEmoji: '🧑',
        health: 10,
        maxHealth: 100,
        hpPercent: 10,
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

function resetStore(screen: ScreenId, player: PlayerSnapshot | null) {
    useGameStore.setState(
        {
            status: 'ready',
            player,
            catalog: null,
            screen,
            highscoreRaceFilter: null,
            flash: null,
            lastBattle: null,
            notice: null,
            soundEnabled: false,
        },
        false,
    );
}

describe('LowHealthAlert', () => {
    beforeEach(() => {
        resetStore('home', makePlayer());
    });

    it('renders nothing when the player is not low on health', () => {
        resetStore('home', makePlayer({ lowHealth: false }));
        const { container } = render(<LowHealthAlert />);
        expect(container).toBeEmptyDOMElement();
    });

    it('renders nothing for a dead player, even if flagged lowHealth', () => {
        resetStore('home', makePlayer({ lowHealth: true, dead: true }));
        const { container } = render(<LowHealthAlert />);
        expect(container).toBeEmptyDOMElement();
    });

    it('renders nothing when there is no player at all', () => {
        resetStore('home', null);
        const { container } = render(<LowHealthAlert />);
        expect(container).toBeEmptyDOMElement();
    });

    it('shows the plain, Inn-linking message when low on health and not ambushed', () => {
        resetStore('home', makePlayer({ lowHealth: true, ambushed: false }));
        render(<LowHealthAlert />);
        expect(screen.getByText(/dangerously low/)).toBeInTheDocument();
        expect(screen.getByRole('link', { name: 'Inn' })).toBeInTheDocument();
    });

    it('shows the ambush-flavored message when low on health and ambushed', () => {
        resetStore('home', makePlayer({ lowHealth: true, ambushed: true }));
        render(<LowHealthAlert />);
        expect(screen.getByText(/dangerously low/)).toBeInTheDocument();
        expect(screen.getByText(/Your warm blood stains/)).toBeInTheDocument();
        expect(screen.queryByRole('link', { name: 'Inn' })).not.toBeInTheDocument();
    });

    it('clicking the Inn link navigates to the Inn screen', () => {
        resetStore('home', makePlayer({ lowHealth: true, ambushed: false }));
        render(<LowHealthAlert />);
        fireEvent.click(screen.getByRole('link', { name: 'Inn' }));
        expect(useGameStore.getState().screen).toBe('inn');
    });

    it('is suppressed on the Suicide screen (matching the old hideLowHealthAlert option)', () => {
        resetStore('suicide', makePlayer({ lowHealth: true, ambushed: false }));
        const { container } = render(<LowHealthAlert />);
        expect(container).toBeEmptyDOMElement();
    });

    it('is suppressed on the Inn screen itself (its own message links there)', () => {
        resetStore('inn', makePlayer({ lowHealth: true, ambushed: false }));
        const { container } = render(<LowHealthAlert />);
        expect(container).toBeEmptyDOMElement();
    });
});
