import { describe, it, expect, vi, beforeEach } from 'vitest';
import { renderHook, waitFor } from '@testing-library/react';

const { requestMock } = vi.hoisted(() => ({ requestMock: vi.fn() }));
vi.mock('@/socket/client', () => ({ request: requestMock }));

const { useRequest } = await import('@/socket/useRequest');
const { useGameStore } = await import('@/store/gameStore');

/** A promise the test resolves by hand, so the in-flight frame can be asserted. */
function deferred<T>() {
    let resolve!: (value: T) => void;
    const promise = new Promise<T>(r => { resolve = r; });

    return { promise, resolve };
}

beforeEach(() => {
    requestMock.mockReset();
    useGameStore.setState({ notice: null }, false);
});

describe('useRequest', () => {
    it('starts out loading, with no data yet', () => {
        requestMock.mockReturnValue(new Promise(() => { /* never settles */ }));

        const { result } = renderHook(() => useRequest('statistics:get', {}));

        expect(result.current.loading).toBe(true);
        expect(result.current.data).toBeUndefined();
    });

    it('exposes the data and stops loading once the request resolves', async () => {
        requestMock.mockResolvedValue({ ok: true, data: { stats: { total_players: 3 } } });

        const { result } = renderHook(() => useRequest('statistics:get', {}));

        await waitFor(() => expect(result.current.loading).toBe(false));
        expect(result.current.data).toEqual({ stats: { total_players: 3 } });
    });

    it('reports loaded-but-empty as data, distinctly from still-loading', async () => {
        requestMock.mockResolvedValue({ ok: true, data: { stats: null } });

        const { result } = renderHook(() => useRequest('statistics:get', {}));

        await waitFor(() => expect(result.current.loading).toBe(false));
        // The whole point of the hook: `data` is defined, so the caller knows a real answer
        // arrived and may legitimately say "there is nothing here".
        expect(result.current.data).toEqual({ stats: null });
    });

    it('re-fetches when the payload changes, by value not identity', async () => {
        requestMock.mockResolvedValue({ ok: true, data: { raceId: null, rows: [] } });

        const { rerender } = renderHook(({ raceId }) => useRequest('highscores:list', { raceId }), {
            initialProps: { raceId: null as number | null },
        });
        await waitFor(() => expect(requestMock).toHaveBeenCalledTimes(1));

        // A fresh object literal with the SAME contents must not re-fetch...
        rerender({ raceId: null });
        expect(requestMock).toHaveBeenCalledTimes(1);

        // ...but a real change must.
        rerender({ raceId: 2 });
        await waitFor(() => expect(requestMock).toHaveBeenCalledTimes(2));
        expect(requestMock).toHaveBeenLastCalledWith('highscores:list', { raceId: 2 });
    });

    it('keeps the previous data on screen while a re-fetch is in flight', async () => {
        const first = { raceId: null, rows: [{ name: 'Legend' }] };
        requestMock.mockResolvedValue({ ok: true, data: first });

        const { result, rerender } = renderHook(({ raceId }) => useRequest('highscores:list', { raceId }), {
            initialProps: { raceId: null as number | null },
        });
        await waitFor(() => expect(result.current.data).toEqual(first));

        const pending = deferred<{ ok: true; data: unknown }>();
        requestMock.mockReturnValue(pending.promise);
        rerender({ raceId: 2 });

        // Mid-refetch: loading again, but the old rows are still there to render.
        await waitFor(() => expect(result.current.loading).toBe(true));
        expect(result.current.data).toEqual(first);

        const second = { raceId: 2, rows: [] };
        pending.resolve({ ok: true, data: second });
        await waitFor(() => expect(result.current.data).toEqual(second));
    });

    it('surfaces a failure as a notice and leaves the data alone', async () => {
        const error = { code: 'INTERNAL' as const, message: '⭕ backend is offline.' };
        requestMock.mockResolvedValue({ ok: false, error });

        const { result } = renderHook(() => useRequest('highscores:list', { raceId: null }));

        await waitFor(() => expect(result.current.loading).toBe(false));
        expect(useGameStore.getState().notice).toEqual(error);
        // Never silently substituted with an empty result — the caller can still tell it never loaded.
        expect(result.current.data).toBeUndefined();
    });

    it('ignores a response that lands after unmount', async () => {
        const pending = deferred<{ ok: true; data: unknown }>();
        requestMock.mockReturnValue(pending.promise);

        const { unmount } = renderHook(() => useRequest('statistics:get', {}));
        unmount();
        pending.resolve({ ok: true, data: { stats: null } });

        // No "state update on an unmounted component" warning, and no notice from a stale ack.
        await Promise.resolve();
        expect(useGameStore.getState().notice).toBeNull();
    });
});
