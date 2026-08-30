import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import { renderHook, act } from '@testing-library/react';
import { useEffectCountdown } from '@/hooks/useEffectCountdown';

const NOW = 1_700_000_000_000;

describe('useEffectCountdown', () => {
    beforeEach(() => {
        vi.useFakeTimers();
        vi.setSystemTime(NOW);
    });

    afterEach(() => {
        vi.useRealTimers();
    });

    it('seeds itself with the current wall-clock time on mount', () => {
        const { result } = renderHook(() => useEffectCountdown());

        expect(result.current).toBe(NOW);
    });

    it('re-reads Date.now() on every one-second tick', () => {
        const { result } = renderHook(() => useEffectCountdown());

        act(() => {
            vi.advanceTimersByTime(1000);
        });
        expect(result.current).toBe(NOW + 1000);

        act(() => {
            vi.advanceTimersByTime(1000);
        });
        expect(result.current).toBe(NOW + 2000);
    });

    it('respects a custom intervalMs — nothing ticks before it elapses', () => {
        const { result } = renderHook(() => useEffectCountdown(5000));

        act(() => {
            vi.advanceTimersByTime(4999);
        });
        expect(result.current).toBe(NOW);

        act(() => {
            vi.advanceTimersByTime(1);
        });
        expect(result.current).toBe(NOW + 5000);
    });

    it('restarts the interval when intervalMs changes, clearing the old one', () => {
        const { result, rerender } = renderHook(({ ms }) => useEffectCountdown(ms), { initialProps: { ms: 1000 } });

        act(() => {
            rerender({ ms: 250 });
        });

        // Exactly one interval is ever live — the 1000ms one was cleared by the effect's cleanup.
        expect(vi.getTimerCount()).toBe(1);

        act(() => {
            vi.advanceTimersByTime(250);
        });
        expect(result.current).toBe(NOW + 250);
    });

    // The whole point of the single-shared-tick design: an unmounted effects row must not leave
    // a 1s interval running for the rest of the session.
    it('clears its interval on unmount', () => {
        const clearSpy = vi.spyOn(globalThis, 'clearInterval');
        const { unmount } = renderHook(() => useEffectCountdown());
        expect(vi.getTimerCount()).toBe(1);

        unmount();

        expect(clearSpy).toHaveBeenCalled();
        expect(vi.getTimerCount()).toBe(0);
        clearSpy.mockRestore();
    });
});
