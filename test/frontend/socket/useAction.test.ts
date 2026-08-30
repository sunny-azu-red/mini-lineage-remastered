import { describe, it, expect, vi, beforeEach } from 'vitest';
import { renderHook, act, waitFor } from '@testing-library/react';
import type { Ack } from '@shared/contract';
import { useGameStore } from '@/store/gameStore';

const { requestMock } = vi.hoisted(() => ({ requestMock: vi.fn() }));

vi.mock('@/socket/client', () => ({
    request: requestMock,
}));

// Imported AFTER the mock so `useAction` picks up the mocked `request`.
const { useAction } = await import('@/socket/useAction');

function resetStore() {
    useGameStore.setState(
        {
            status: 'connecting',
            player: null,
            catalog: null,
            screen: 'home',
            highscoreRaceFilter: null,
            flash: null,
            lastBattle: null,
            notice: null,
            soundEnabled: true,
        },
        false,
    );
}

describe('useAction', () => {
    beforeEach(() => {
        requestMock.mockReset();
        resetStore();
    });

    it('prevents double-submit while pending', async () => {
        let resolveRequest!: (value: Ack<any>) => void;
        requestMock.mockReturnValue(
            new Promise<Ack<any>>(resolve => {
                resolveRequest = resolve;
            }),
        );

        const { result } = renderHook(() => useAction('player:suicide'));

        let firstCallDone = false;
        let secondCallDone = false;
        act(() => {
            void result.current.run({}).then(() => {
                firstCallDone = true;
            });
            void result.current.run({}).then(() => {
                secondCallDone = true;
            });
        });

        expect(requestMock).toHaveBeenCalledTimes(1);
        expect(result.current.pending).toBe(true);

        await act(async () => {
            resolveRequest({ ok: true, data: { player: {} as any, flash: null } });
            await Promise.resolve();
        });

        await waitFor(() => {
            expect(firstCallDone).toBe(true);
            expect(secondCallDone).toBe(true);
        });
        expect(requestMock).toHaveBeenCalledTimes(1);
    });

    it('calls onSuccess with ack data on success', async () => {
        const data = { player: { name: 'Hero' } as any, flash: null };
        requestMock.mockResolvedValue({ ok: true, data });

        const { result } = renderHook(() => useAction('player:suicide'));
        const onSuccess = vi.fn();

        await act(async () => {
            await result.current.run({}, { onSuccess });
        });

        expect(onSuccess).toHaveBeenCalledWith(data);
        expect(useGameStore.getState().notice).toBeNull();
        expect(result.current.pending).toBe(false);
    });

    it('sets notice (does not navigate) on other error codes', async () => {
        const error = { code: 'RATE_LIMITED' as const, message: 'Slow down.', retryAfterMs: 500 };
        requestMock.mockResolvedValue({ ok: false, error });

        const { result } = renderHook(() => useAction('shop:purchase'));
        const onSuccess = vi.fn();

        await act(async () => {
            await result.current.run({ type: 'food', itemId: 0 }, { onSuccess });
        });

        expect(onSuccess).not.toHaveBeenCalled();
        expect(useGameStore.getState().screen).toBe('home');
        expect(useGameStore.getState().notice).toEqual(error);
    });
});
