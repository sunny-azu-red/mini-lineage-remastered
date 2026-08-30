import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, fireEvent } from '@testing-library/react';

const { requestMock } = vi.hoisted(() => ({ requestMock: vi.fn() }));
vi.mock('@/socket/client', () => ({ request: requestMock }));

const { useGameStore } = await import('@/store/gameStore');
const { default: BackLink } = await import('@/components/common/BackLink');
const { makePlayer } = await import('../../factories');

beforeEach(() => {
    requestMock.mockResolvedValue({ ok: false, error: { code: 'INTERNAL', message: 'mock' } });
    useGameStore.setState({ player: null, screen: 'statistics' }, false);
});

describe('BackLink', () => {
    it('defaults to the started wording and navigates home for a started player', () => {
        useGameStore.setState({ player: makePlayer({ started: true }) }, false);
        render(<BackLink />);

        const link = screen.getByRole('link', { name: 'Continue your journey' });
        fireEvent.click(link);

        expect(useGameStore.getState().screen).toBe('home');
    });

    it('defaults to the unstarted wording and navigates to start with no character', () => {
        render(<BackLink />);

        const link = screen.getByRole('link', { name: 'Go back to game start' });
        fireEvent.click(link);

        expect(useGameStore.getState().screen).toBe('start');
    });

    it('treats a player snapshot with started:false as unstarted', () => {
        useGameStore.setState({ player: makePlayer({ started: false }) }, false);
        render(<BackLink />);

        expect(screen.getByRole('link', { name: 'Go back to game start' })).toBeInTheDocument();
    });

    it('honours an explicit label and the default "last back" wrapper class', () => {
        const { container } = render(<BackLink label="Return to safer lands" />);

        expect(screen.getByRole('link', { name: 'Return to safer lands' })).toBeInTheDocument();
        expect(container.querySelector('p')?.className).toBe('last back');
    });

    it('honours an explicit wrapper class', () => {
        const { container } = render(<BackLink className="last" />);

        expect(container.querySelector('p')?.className).toBe('last');
    });

    it('prevents the anchor default so the page never actually navigates', () => {
        render(<BackLink />);

        const event = new MouseEvent('click', { bubbles: true, cancelable: true });
        screen.getByRole('link').dispatchEvent(event);

        expect(event.defaultPrevented).toBe(true);
    });
});
