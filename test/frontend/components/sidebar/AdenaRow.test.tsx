import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import { render, act } from '@testing-library/react';
import type { PlayerSnapshot } from '@shared/contract';
import AdenaRow from '@/components/sidebar/AdenaRow';

function stubMatchMedia(matches: boolean) {
    Object.defineProperty(window, 'matchMedia', {
        writable: true,
        configurable: true,
        value: vi.fn().mockImplementation((query: string) => ({
            matches, media: query, onchange: null,
            addListener: vi.fn(), removeListener: vi.fn(),
            addEventListener: vi.fn(), removeEventListener: vi.fn(), dispatchEvent: vi.fn(),
        })),
    });
}

function makePlayer(overrides: Partial<PlayerSnapshot> = {}): PlayerSnapshot {
    return {
        revision: 1, started: true, name: 'Hero', raceId: 1, raceLabel: 'Human', raceEmoji: '🧑',
        health: 80, maxHealth: 100, hpPercent: 80, lowHealth: false,
        experience: 10, level: 2, isMaxLevel: false, xpCurrent: 90, xpRequired: 100, xpPercent: 90, xpNeeded: 10,
        adena: 500, weapon: null, armor: null, stats: null, effects: [],
        dead: false, ambushed: false, coward: false, cheated: false, deathReason: null, highscoreEligible: false,
        counters: { totalBattles: 0, totalAmbushes: 0, consecutiveAmbushes: 0, totalEnemiesKilled: 0 },
        lastBattle: null,
        ...overrides,
    };
}

describe('AdenaRow', () => {
    beforeEach(() => {
        vi.useFakeTimers();
        stubMatchMedia(false);
    });

    afterEach(() => {
        vi.useRealTimers();
    });

    it('renders the true formatted value instantly on first mount (no 0→N sweep)', () => {
        const { getByText } = render(<AdenaRow player={makePlayer({ adena: 500 })} />);
        expect(getByText('500')).toBeInTheDocument();
    });

    it('animates toward a higher value over time on a gain (e.g. a battle reward)', () => {
        const { rerender, getByText } = render(<AdenaRow player={makePlayer({ adena: 500 })} />);

        act(() => {
            rerender(<AdenaRow player={makePlayer({ adena: 800 })} />);
        });
        act(() => {
            vi.advanceTimersByTime(300);
        });

        const midValue = Number(getByText(/^\d+$/).textContent);
        expect(midValue).toBeGreaterThan(500);
        expect(midValue).toBeLessThan(800);

        act(() => {
            vi.advanceTimersByTime(400);
        });
        expect(getByText('800')).toBeInTheDocument();
    });

    it('animates toward a lower value over time on a loss (e.g. a purchase)', () => {
        const { rerender, getByText } = render(<AdenaRow player={makePlayer({ adena: 500 })} />);

        act(() => {
            rerender(<AdenaRow player={makePlayer({ adena: 100 })} />);
        });
        act(() => {
            vi.advanceTimersByTime(700);
        });
        expect(getByText('100')).toBeInTheDocument();
    });
});
