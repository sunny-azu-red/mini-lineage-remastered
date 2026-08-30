import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import { render, act } from '@testing-library/react';
import HpBar from '@/components/sidebar/HpBar';
import { makePlayer } from '../../factories';

// The defaults this file's assertions were written against.
const localPlayer = (o: Partial<Parameters<typeof makePlayer>[0]> = {}) =>
    makePlayer({ xpCurrent: 90, xpPercent: 90, xpNeeded: 10, ...o });

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

describe('HpBar', () => {
    beforeEach(() => {
        vi.useFakeTimers();
        stubMatchMedia(false);
    });

    afterEach(() => {
        vi.useRealTimers();
    });

    it('renders the current width and true value instantly on first mount (no 0→N sweep)', () => {
        const { container } = render(<HpBar player={localPlayer({ health: 80, hpPercent: 80 })} />);

        const bar = container.querySelector('.hp-bar') as HTMLElement;
        expect(bar.style.width).toBe('80%');
        expect(container.querySelector('.animate-val')?.textContent).toBe('80');
    });

    it('animates the HP number toward a higher value over time on a gain (e.g. food/regen)', () => {
        const { rerender, container } = render(<HpBar player={localPlayer({ health: 50, hpPercent: 50 })} />);

        act(() => {
            rerender(<HpBar player={localPlayer({ health: 90, hpPercent: 90 })} />);
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
        const { rerender, container } = render(<HpBar player={localPlayer({ health: 50, hpPercent: 50 })} />);

        act(() => {
            rerender(<HpBar player={localPlayer({ health: 30, hpPercent: 30 })} />);
        });
        expect(container.querySelector('.hp-bar.shimmer-active')).toBeNull();

        act(() => {
            rerender(<HpBar player={localPlayer({ health: 70, hpPercent: 70 })} />);
        });
        expect(container.querySelector('.hp-bar.shimmer-active')).not.toBeNull();
    });

    it('applies the "danger" row class when lowHealth is true', () => {
        const { container } = render(<HpBar player={localPlayer({ lowHealth: true })} />);
        expect(container.querySelector('.stat-row.bar.danger')).not.toBeNull();
    });

    it('omits the "danger" row class when lowHealth is false', () => {
        const { container } = render(<HpBar player={localPlayer({ lowHealth: false })} />);
        expect(container.querySelector('.stat-row.bar.danger')).toBeNull();
        expect(container.querySelector('.stat-row.bar')).not.toBeNull();
    });

    // health/maxHealth are both null on a snapshot for a character that has not been started
    // yet — render plain zeroes rather than "NaN"/"null".
    it('falls back to 0/0 when the snapshot carries null health and maxHealth', () => {
        const { container } = render(<HpBar player={localPlayer({ health: null, maxHealth: null, hpPercent: 0 })} />);

        expect(container.querySelector('.animate-val')?.textContent).toBe('0');
        expect(container.querySelector('#status-max-hp')?.textContent).toBe('0');
    });
});
