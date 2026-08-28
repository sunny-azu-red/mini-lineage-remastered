import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, fireEvent } from '@testing-library/react';
import type { PlayerSnapshot } from '@shared/contract';
import { useGameStore } from '@/store/gameStore';

vi.mock('@/socket/client', () => ({ request: vi.fn() }));

const { default: SiteHeader } = await import('./SiteHeader');

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

function setPlayer(player: PlayerSnapshot | null) {
    useGameStore.setState({ player }, false);
}

describe('SiteHeader', () => {
    beforeEach(() => {
        useGameStore.setState({ screen: 'home' }, false);
    });

    it('is clickable and navigates to home when the player has started, is alive, and is not ambushed', () => {
        setPlayer(makePlayer({ started: true, ambushed: false, dead: false }));
        render(<SiteHeader />);

        const link = screen.getByRole('link');
        fireEvent.click(link);

        expect(useGameStore.getState().screen).toBe('home');
    });

    it('is clickable and navigates to start when no character exists yet', () => {
        setPlayer(null);
        render(<SiteHeader />);

        const link = screen.getByRole('link');
        fireEvent.click(link);

        expect(useGameStore.getState().screen).toBe('start');
    });

    it('is clickable and navigates to start when the player exists but has not started', () => {
        setPlayer(makePlayer({ started: false }));
        render(<SiteHeader />);

        const link = screen.getByRole('link');
        fireEvent.click(link);

        expect(useGameStore.getState().screen).toBe('start');
    });

    it('is NOT clickable while ambushed', () => {
        setPlayer(makePlayer({ started: true, ambushed: true }));
        render(<SiteHeader />);

        expect(screen.queryByRole('link')).not.toBeInTheDocument();
        useGameStore.getState().navigate('battle');
        expect(useGameStore.getState().screen).toBe('battle');
    });

    it('is NOT clickable while dead', () => {
        setPlayer(makePlayer({ started: true, dead: true }));
        render(<SiteHeader />);

        expect(screen.queryByRole('link')).not.toBeInTheDocument();
    });

    it('always renders the SoundToggle mute button regardless of clickability, and it is outside the clickable link', () => {
        setPlayer(makePlayer({ started: true, ambushed: true }));
        render(<SiteHeader />);

        const soundButton = screen.getByRole('button', { name: /Sound FX/i });
        expect(soundButton).toBeInTheDocument();
        // No enclosing <a> anywhere in the tree since the header isn't clickable here.
        expect(screen.queryByRole('link')).not.toBeInTheDocument();
    });

    it('keeps the SoundToggle outside the clickable <a> when the header IS clickable', () => {
        setPlayer(makePlayer({ started: true, ambushed: false, dead: false }));
        render(<SiteHeader />);

        const link = screen.getByRole('link');
        const soundButton = screen.getByRole('button', { name: /Sound FX/i });
        expect(link.contains(soundButton)).toBe(false);
    });
});
