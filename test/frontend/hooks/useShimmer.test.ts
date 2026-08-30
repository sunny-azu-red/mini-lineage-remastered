import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import { renderHook, act } from '@testing-library/react';
import { useShimmer } from '@/hooks/useShimmer';

describe('useShimmer', () => {
    beforeEach(() => {
        vi.useFakeTimers();
    });

    afterEach(() => {
        vi.useRealTimers();
    });

    it('is false on initial mount, even with a non-zero initial trigger', () => {
        const { result } = renderHook(({ trigger }) => useShimmer(trigger), {
            initialProps: { trigger: 1 },
        });

        expect(result.current).toBe(false);
    });

    it('becomes true when the trigger changes', () => {
        const { result, rerender } = renderHook(({ trigger }) => useShimmer(trigger), {
            initialProps: { trigger: 0 },
        });

        expect(result.current).toBe(false);

        rerender({ trigger: 1 });
        expect(result.current).toBe(true);
    });

    it('resets to false after the timeout elapses', () => {
        const { result, rerender } = renderHook(({ trigger }) => useShimmer(trigger, 600), {
            initialProps: { trigger: 0 },
        });

        rerender({ trigger: 1 });
        expect(result.current).toBe(true);

        act(() => {
            vi.advanceTimersByTime(599);
        });
        expect(result.current).toBe(true);

        act(() => {
            vi.advanceTimersByTime(1);
        });
        expect(result.current).toBe(false);
    });

    it('restarts the timeout when the trigger changes again mid-flight', () => {
        const { result, rerender } = renderHook(({ trigger }) => useShimmer(trigger, 600), {
            initialProps: { trigger: 0 },
        });

        rerender({ trigger: 1 });
        act(() => {
            vi.advanceTimersByTime(400);
        });
        expect(result.current).toBe(true);

        // Retrigger before the first timeout would have fired.
        rerender({ trigger: 2 });
        act(() => {
            vi.advanceTimersByTime(400);
        });
        // 800ms since the first trigger, but only 400ms since the second — still active.
        expect(result.current).toBe(true);

        act(() => {
            vi.advanceTimersByTime(200);
        });
        expect(result.current).toBe(false);
    });
});
