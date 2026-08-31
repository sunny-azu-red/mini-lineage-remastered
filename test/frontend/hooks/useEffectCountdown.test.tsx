import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import { render, act } from '@testing-library/react';
import { useEffectCountdown } from '@/hooks/useEffectCountdown';
import { useGameStore } from '@/store/gameStore';

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
        useGameStore.setState({ clockOffsetMs: 0 });
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

    /**
     * `expiresAt` is stamped by the server, so this must report SERVER time. Counting down against
     * local time let any skew between the machines shift every effect timer.
     */
    it('reports server time by applying the measured clock offset', () => {
        useGameStore.setState({ clockOffsetMs: 4_000 });

        const { getByTestId } = render(<Probe renders={{ count: 0 }} />);

        expect(getByTestId('now').textContent).toBe(String(NOW + 4_000));
    });

    it('applies a negative offset, for a server clock that is behind', () => {
        useGameStore.setState({ clockOffsetMs: -1_500 });

        const { getByTestId } = render(<Probe renders={{ count: 0 }} />);

        expect(getByTestId('now').textContent).toBe(String(NOW - 1_500));
    });

    // Subscribed, not read once: a countdown must not stay uncorrected until the next interval tick.
    it('re-renders as soon as a measurement lands, without waiting for the interval', () => {
        const { getByTestId } = render(<Probe renders={{ count: 0 }} />);
        expect(getByTestId('now').textContent).toBe(String(NOW));

        act(() => {
            useGameStore.setState({ clockOffsetMs: 2_000 });
        });

        expect(getByTestId('now').textContent).toBe(String(NOW + 2_000));
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
