import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import { render, act } from '@testing-library/react';
import { useEffectCountdown } from '@/hooks/useEffectCountdown';

const NOW = 1_700_000_000_000;

/** Renders the hook's value and counts how many times it re-rendered. */
function Probe({ intervalMs, renders }: { intervalMs?: number; renders: { count: number } }) {
    const now = useEffectCountdown(intervalMs);
    renders.count += 1;

    return <span data-testid="now">{now}</span>;
}

describe('useEffectCountdown', () => {
    beforeEach(() => {
        vi.useFakeTimers();
        vi.setSystemTime(NOW);
    });

    afterEach(() => {
        vi.useRealTimers();
    });

    it('reports the current time on first render', () => {
        const { getByTestId } = render(<Probe renders={{ count: 0 }} />);

        expect(getByTestId('now').textContent).toBe(String(NOW));
    });

    it('re-renders on its interval, reporting the advanced time', () => {
        const renders = { count: 0 };
        const { getByTestId } = render(<Probe renders={renders} />);
        const initial = renders.count;

        act(() => {
            vi.advanceTimersByTime(1000);
        });

        expect(getByTestId('now').textContent).toBe(String(NOW + 1000));
        expect(renders.count).toBeGreaterThan(initial);
    });

    /**
     * The whole point of reading the clock at render rather than holding it in state. A render
     * caused by anything OTHER than the interval — a server push adding an effect — must still
     * measure the real time. Holding it in state returned a value up to a full second stale, and
     * `Math.ceil` turned that into a countdown that opened one too high.
     */
    it('reports the real time on a render the interval did not cause', () => {
        const renders = { count: 0 };
        const { getByTestId, rerender } = render(<Probe renders={renders} />);

        // Short of the 1000ms interval, so it has not fired: state-held `now` would still read NOW.
        act(() => {
            vi.advanceTimersByTime(500);
        });
        rerender(<Probe renders={renders} />);

        expect(getByTestId('now').textContent).toBe(String(NOW + 500));
    });

    it('honours a custom interval', () => {
        const { getByTestId } = render(<Probe intervalMs={250} renders={{ count: 0 }} />);

        act(() => {
            vi.advanceTimersByTime(250);
        });

        expect(getByTestId('now').textContent).toBe(String(NOW + 250));
    });

    it('clears its interval on unmount', () => {
        const clearSpy = vi.spyOn(global, 'clearInterval');
        const { unmount } = render(<Probe renders={{ count: 0 }} />);

        unmount();

        expect(clearSpy).toHaveBeenCalled();
    });
});
