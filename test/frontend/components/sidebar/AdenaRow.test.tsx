import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import { render, act } from '@testing-library/react';
import AdenaRow from '@/components/sidebar/AdenaRow';
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

describe('AdenaRow', () => {
    beforeEach(() => {
        vi.useFakeTimers();
        stubMatchMedia(false);
    });

    afterEach(() => {
        vi.useRealTimers();
    });

    it('renders the true formatted value instantly on first mount (no 0→N sweep)', () => {
        const { getByText } = render(<AdenaRow player={localPlayer({ adena: 500 })} />);
        expect(getByText('500')).toBeInTheDocument();
    });

    it('animates toward a higher value over time on a gain (e.g. a battle reward)', () => {
        const { rerender, getByText } = render(<AdenaRow player={localPlayer({ adena: 500 })} />);

        act(() => {
            rerender(<AdenaRow player={localPlayer({ adena: 800 })} />);
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
        const { rerender, getByText } = render(<AdenaRow player={localPlayer({ adena: 500 })} />);

        act(() => {
            rerender(<AdenaRow player={localPlayer({ adena: 100 })} />);
        });
        act(() => {
            vi.advanceTimersByTime(700);
        });
        expect(getByText('100')).toBeInTheDocument();
    });

    // `adena` is null on a snapshot for a character that has not been started yet — render a
    // plain 0 rather than "NaN"/"null".
    it('falls back to 0 when the snapshot carries a null adena', () => {
        const { container } = render(<AdenaRow player={localPlayer({ adena: null })} />);

        expect(container.querySelector('.animate-adena')?.textContent).toBe('0');
    });
});
