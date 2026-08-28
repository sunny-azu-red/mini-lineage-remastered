import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import { renderHook, act } from '@testing-library/react';
import { useAnimatedNumber } from '@/hooks/useAnimatedNumber';

function stubMatchMedia(matches: boolean) {
    Object.defineProperty(window, 'matchMedia', {
        writable: true,
        configurable: true,
        value: vi.fn().mockImplementation((query: string) => ({
            matches,
            media: query,
            onchange: null,
            addListener: vi.fn(),
            removeListener: vi.fn(),
            addEventListener: vi.fn(),
            removeEventListener: vi.fn(),
            dispatchEvent: vi.fn(),
        })),
    });
}

describe('useAnimatedNumber', () => {
    beforeEach(() => {
        vi.useFakeTimers();
        stubMatchMedia(false);
    });

    afterEach(() => {
        vi.useRealTimers();
    });

    it('renders the first target instantly with no 0→N sweep', () => {
        const { result } = renderHook(() => useAnimatedNumber(500));

        // No time has passed at all — if this were mid-sweep it would show something less than
        // 500. This is the exact behavior that replaces the old sessionStorage/pre-paint hack:
        // a fresh mount (including right after a `hydrate` reconnect) must show the true value
        // immediately.
        expect(result.current.display).toBe('500');
        expect(result.current.direction).toBe(0);
    });

    it('eases toward a new target over time when retargeted', () => {
        const { result, rerender } = renderHook(({ target }) => useAnimatedNumber(target), {
            initialProps: { target: 0 },
        });
        expect(result.current.display).toBe('0');

        rerender({ target: 600 });
        expect(result.current.direction).toBe(1);

        // Kick off the rAF loop's first frame, then advance partway through the animation.
        act(() => {
            vi.advanceTimersByTime(300);
        });
        const midValue = Number(result.current.display.replace(/,/g, ''));
        expect(midValue).toBeGreaterThan(0);
        expect(midValue).toBeLessThan(600);

        act(() => {
            vi.advanceTimersByTime(600);
        });
        expect(result.current.display).toBe('600');
    });

    it('reports direction -1 when the target decreases', () => {
        const { result, rerender } = renderHook(({ target }) => useAnimatedNumber(target), {
            initialProps: { target: 100 },
        });

        rerender({ target: 40 });
        expect(result.current.direction).toBe(-1);

        act(() => {
            vi.advanceTimersByTime(600);
        });
        expect(result.current.display).toBe('40');
    });

    it('cancels an in-flight animation when retargeted mid-flight, settling on the latest target', () => {
        const { result, rerender } = renderHook(({ target }) => useAnimatedNumber(target), {
            initialProps: { target: 0 },
        });

        rerender({ target: 1000 });
        act(() => {
            vi.advanceTimersByTime(200);
        });
        const midValue = Number(result.current.display.replace(/,/g, ''));
        expect(midValue).toBeGreaterThan(0);
        expect(midValue).toBeLessThan(1000);

        // Retarget mid-flight before the first animation would have finished.
        rerender({ target: 50 });
        expect(result.current.direction).toBe(-1);

        act(() => {
            vi.advanceTimersByTime(600);
        });
        // Settles cleanly on the latest target — no leftover frame from the cancelled animation
        // ever overwrites this with a stale value from the 0→1000 run.
        expect(result.current.display).toBe('50');
    });

    it('snaps instantly on every change when prefers-reduced-motion is set', () => {
        stubMatchMedia(true);

        const { result, rerender } = renderHook(({ target }) => useAnimatedNumber(target), {
            initialProps: { target: 10 },
        });
        expect(result.current.display).toBe('10');

        rerender({ target: 999 });
        // No timer advance at all — must already be at the final value.
        expect(result.current.display).toBe('999');
        expect(result.current.direction).toBe(1);
    });

    it('uses the provided format function', () => {
        const { result } = renderHook(() => useAnimatedNumber(1234, { format: n => `$${n}` }));
        expect(result.current.display).toBe('$1234');
    });
});
