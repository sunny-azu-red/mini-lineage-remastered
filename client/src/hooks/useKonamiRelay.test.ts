import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { renderHook } from '@testing-library/react';
import { useKonamiRelay } from './useKonamiRelay';

const { socketEmitMock } = vi.hoisted(() => ({ socketEmitMock: vi.fn() }));
vi.mock('@/socket/client', () => ({ socket: { emit: socketEmitMock } }));

function dispatchKeyDown(init: KeyboardEventInit, target: EventTarget = window): void {
    target.dispatchEvent(new KeyboardEvent('keydown', { bubbles: true, ...init }));
}

describe('useKonamiRelay', () => {
    beforeEach(() => {
        socketEmitMock.mockReset();
    });

    afterEach(() => {
        document.body.innerHTML = '';
    });

    it('relays a plain keydown outside text inputs as a lowercased input event', () => {
        renderHook(() => useKonamiRelay());

        dispatchKeyDown({ key: 'ArrowUp' });

        expect(socketEmitMock).toHaveBeenCalledWith('input', { key: 'arrowup' });
        expect(socketEmitMock).toHaveBeenCalledTimes(1);
    });

    it('ignores a repeated keydown (key held down)', () => {
        renderHook(() => useKonamiRelay());

        dispatchKeyDown({ key: 'a', repeat: true });

        expect(socketEmitMock).not.toHaveBeenCalled();
    });

    it('ignores a keydown targeting an <input>', () => {
        renderHook(() => useKonamiRelay());

        const input = document.createElement('input');
        document.body.appendChild(input);

        dispatchKeyDown({ key: 'a' }, input);

        expect(socketEmitMock).not.toHaveBeenCalled();
    });

    it('ignores a keydown targeting a <textarea>', () => {
        renderHook(() => useKonamiRelay());

        const textarea = document.createElement('textarea');
        document.body.appendChild(textarea);

        dispatchKeyDown({ key: 'a' }, textarea);

        expect(socketEmitMock).not.toHaveBeenCalled();
    });

    it('removes its listener on unmount', () => {
        const { unmount } = renderHook(() => useKonamiRelay());
        unmount();

        dispatchKeyDown({ key: 'a' });

        expect(socketEmitMock).not.toHaveBeenCalled();
    });
});
