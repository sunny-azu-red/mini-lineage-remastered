import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, fireEvent } from '@testing-library/react';
import { useGameStore } from '@/store/gameStore';
import { makePlayer } from '../../factories';

const { requestMock } = vi.hoisted(() => ({ requestMock: vi.fn() }));
vi.mock('@/socket/client', () => ({ request: requestMock }));

const { default: StatusPanel } = await import('@/components/sidebar/StatusPanel');

function resetStore(overrides: Partial<ReturnType<typeof useGameStore.getState>> = {}) {
    useGameStore.setState(
        {
            status: 'ready',
            player: makePlayer(),
            catalog: null,
            screen: 'home',
            highscoreRaceFilter: null,
            flash: null,
            lastBattle: null,
            notice: null,
            soundEnabled: false,
            ...overrides,
        },
        false,
    );
}

describe('StatusPanel', () => {
    beforeEach(() => {
        requestMock.mockReset();
        // navigate() always calls .then() on this now (to apply the player:screen ack to its
        // own store) — a safe default so tests that don't care about the response don't crash.
        requestMock.mockResolvedValue({ ok: false, error: { code: 'INTERNAL', message: 'mock default' } });
        resetStore();
    });

    it('renders nothing at all when there is no player yet', () => {
        resetStore({ player: null });
        const { container } = render(<StatusPanel />);

        expect(container).toBeEmptyDOMElement();
    });

    it('renders the name header plus the reconstructed race/level line', () => {
        render(<StatusPanel />);

        expect(screen.getByText('Hero')).toBeInTheDocument();
        expect(screen.getByRole('link', { name: 'Human level 2' })).toBeInTheDocument();
    });

    it('shows the race emoji while alive and the skull once dead', () => {
        const { container, unmount } = render(<StatusPanel />);
        expect(container.textContent).toContain('🧑');
        unmount();

        resetStore({ player: makePlayer({ dead: true }) });
        const { container: deadContainer } = render(<StatusPanel />);
        expect(deadContainer.textContent).toContain('☠️');
        expect(deadContainer.textContent).not.toContain('🧑');
    });

    it('falls back to empty/zero pieces when raceLabel/level/raceEmoji are still null', () => {
        resetStore({ player: makePlayer({ raceLabel: null, raceEmoji: null, level: null }) });
        render(<StatusPanel />);

        expect(screen.getByRole('link', { name: 'level 0' })).toBeInTheDocument();
    });

    // The old EJS gated this link server-side on ambushed/dead; the store's navigate() now pins
    // the screen itself, so the link is always live and simply gets redirected when it must be.
    it('the race/level link navigates to the Character screen and suppresses the anchor default', () => {
        render(<StatusPanel />);

        const link = screen.getByRole('link', { name: 'Human level 2' });
        const clicked = fireEvent.click(link);

        // fireEvent returns false once preventDefault() has been called on the dispatched event.
        expect(clicked).toBe(false);
        expect(useGameStore.getState().screen).toBe('character');
    });

    it('still lets an ambushed player click through — the store pins them straight back to battle', () => {
        resetStore({ player: makePlayer({ ambushed: true }), screen: 'battle' });
        render(<StatusPanel />);

        fireEvent.click(screen.getByRole('link', { name: 'Human level 2' }));

        expect(useGameStore.getState().screen).toBe('battle');
    });

    it('mounts the HP/XP/Adena rows underneath', () => {
        const { container } = render(<StatusPanel />);

        expect(container.querySelector('#hp-bar')).not.toBeNull();
        expect(container.querySelector('#xp-bar')).not.toBeNull();
        expect(container.querySelector('.animate-adena')?.textContent).toBe('500');
    });
});
