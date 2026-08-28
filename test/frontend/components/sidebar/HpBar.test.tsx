import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import { render, act } from '@testing-library/react';
import type { PlayerSnapshot } from '@shared/contract';
import HpBar from '@/components/sidebar/HpBar';

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

describe('HpBar', () => {
    beforeEach(() => {
        vi.useFakeTimers();
        stubMatchMedia(false);
    });

    afterEach(() => {
        vi.useRealTimers();
    });

    it('renders the current width and true value instantly on first mount (no 0→N sweep)', () => {
        const { container } = render(<HpBar player={makePlayer({ health: 80, hpPercent: 80 })} />);

        const bar = container.querySelector('.hp-bar') as HTMLElement;
        expect(bar.style.width).toBe('80%');
        expect(container.querySelector('.animate-val')?.textContent).toBe('80');
    });

    it('animates the HP number toward a higher value over time on a gain (e.g. food/regen)', () => {
        const { rerender, container } = render(<HpBar player={makePlayer({ health: 50, hpPercent: 50 })} />);

        act(() => {
            rerender(<HpBar player={makePlayer({ health: 90, hpPercent: 90 })} />);
        });
        act(() => {
            vi.advanceTimersByTime(300);
        });

        const midValue = Number(container.querySelector('.animate-val')?.textContent);
        expect(midValue).toBeGreaterThan(50);
        expect(midValue).toBeLessThan(90);

        act(() => {
            vi.advanceTimersByTime(400);
        });
        expect(container.querySelector('.animate-val')?.textContent).toBe('90');
    });

    it('shimmers on an HP increase but not on a decrease (damage)', () => {
        const { rerender, container } = render(<HpBar player={makePlayer({ health: 50, hpPercent: 50 })} />);

        act(() => {
            rerender(<HpBar player={makePlayer({ health: 30, hpPercent: 30 })} />);
        });
        expect(container.querySelector('.hp-bar.shimmer-active')).toBeNull();

        act(() => {
            rerender(<HpBar player={makePlayer({ health: 70, hpPercent: 70 })} />);
        });
        expect(container.querySelector('.hp-bar.shimmer-active')).not.toBeNull();
    });

    it('applies the "danger" row class when lowHealth is true', () => {
        const { container } = render(<HpBar player={makePlayer({ lowHealth: true })} />);
        expect(container.querySelector('.stat-row.bar.danger')).not.toBeNull();
    });
});
