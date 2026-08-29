import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, fireEvent } from '@testing-library/react';
import type { PlayerSnapshot } from '@shared/contract';
import { useGameStore } from '@/store/gameStore';

// navigate() always calls .then() on this now (to apply the player:screen ack to its own
// store) — needs a resolved default so tests that don't care about the response don't crash.
vi.mock('@/socket/client', () => ({
    request: vi.fn().mockResolvedValue({ ok: false, error: { code: 'INTERNAL', message: 'mock default' } }),
}));

const { default: SiteHeader } = await import('@/components/layout/SiteHeader');

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

    it('is clickable while ambushed — the store transparently redirects the resulting navigate() to battle', () => {
        setPlayer(makePlayer({ started: true, ambushed: true }));
        render(<SiteHeader />);

        const link = screen.getByRole('link');
        fireEvent.click(link);

        // The header itself no longer knows or cares about ambush state — it fires a normal
        // `navigate('home')` and the store's pin-to-battle invariant (tested in gameStore.test.ts)
        // is what actually redirects this to 'battle'.
        expect(useGameStore.getState().screen).toBe('battle');
    });

    it('is still clickable while dead — the store transparently redirects the resulting navigate() to death', () => {
        setPlayer(makePlayer({ started: true, dead: true }));
        render(<SiteHeader />);

        const link = screen.getByRole('link');
        fireEvent.click(link);

        // The header itself no longer knows or cares about dead state — it fires a normal
        // `navigate('home')` and the store's pin-to-death invariant (tested in gameStore.test.ts)
        // is what actually redirects this to 'death'.
        expect(useGameStore.getState().screen).toBe('death');
    });

    it('always renders the SoundToggle mute button outside the clickable link', () => {
        setPlayer(makePlayer({ started: true, dead: true }));
        render(<SiteHeader />);

        const soundButton = screen.getByRole('button', { name: /Sound FX/i });
        expect(soundButton).toBeInTheDocument();
        const link = screen.getByRole('link');
        expect(link).not.toContainElement(soundButton);
    });

    it('keeps the SoundToggle outside the clickable <a> when the header IS clickable', () => {
        setPlayer(makePlayer({ started: true, ambushed: false, dead: false }));
        render(<SiteHeader />);

        const link = screen.getByRole('link');
        const soundButton = screen.getByRole('button', { name: /Sound FX/i });
        expect(link.contains(soundButton)).toBe(false);
    });
});
