import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, fireEvent } from '@testing-library/react';
import type { PlayerSnapshot } from '@shared/contract';
import { useGameStore } from '@/store/gameStore';
import { makePlayer } from '../../factories';

// navigate() always calls .then() on this now (to apply the player:screen ack to its own
// store) — needs a resolved default so tests that don't care about the response don't crash.
vi.mock('@/socket/client', () => ({
    request: vi.fn().mockResolvedValue({ ok: false, error: { code: 'INTERNAL', message: 'mock default' } }),
}));

const { default: SiteHeader } = await import('@/components/layout/SiteHeader');
const { request: requestMock } = vi.mocked(await import('@/socket/client'));

function setPlayer(player: PlayerSnapshot | null) {
    useGameStore.setState({ player }, false);
}

describe('SiteHeader', () => {
    beforeEach(() => {
        useGameStore.setState({ screen: 'home' }, false);
    });

    it('is clickable and navigates to home when the player has started, is alive, and is not ambushed', () => {
        setPlayer(makePlayer({ started: true, ambushed: false, dead: false }));
        render(<SiteHeader />);

        const link = screen.getByRole('link');
        fireEvent.click(link);

        expect(useGameStore.getState().screen).toBe('home');
    });

    it('is clickable and navigates to start when no character exists yet', () => {
        setPlayer(null);
        render(<SiteHeader />);

        const link = screen.getByRole('link');
        fireEvent.click(link);

        expect(useGameStore.getState().screen).toBe('start');
    });

    it('is clickable and navigates to start when the player exists but has not started', () => {
        setPlayer(makePlayer({ started: false }));
        render(<SiteHeader />);

        const link = screen.getByRole('link');
        fireEvent.click(link);

        expect(useGameStore.getState().screen).toBe('start');
    });

    it('is clickable while ambushed — the store transparently redirects the resulting navigate() to battle', () => {
        setPlayer(makePlayer({ started: true, ambushed: true }));
        render(<SiteHeader />);

        const link = screen.getByRole('link');
        fireEvent.click(link);

        // The header itself no longer knows or cares about ambush state — it fires a normal
        // `navigate('home')` and the store's pin-to-battle invariant (tested in gameStore.test.ts)
        // is what actually redirects this to 'battle'.
        expect(useGameStore.getState().screen).toBe('battle');
    });

    it('is still clickable while dead — the store transparently redirects the resulting navigate() to death', () => {
        setPlayer(makePlayer({ started: true, dead: true }));
        render(<SiteHeader />);

        const link = screen.getByRole('link');
        fireEvent.click(link);

        // The header itself no longer knows or cares about dead state — it fires a normal
        // `navigate('home')` and the store's pin-to-death invariant (tested in gameStore.test.ts)
        // is what actually redirects this to 'death'.
        expect(useGameStore.getState().screen).toBe('death');
    });

    it('always renders the SoundToggle mute button outside the clickable link', () => {
        setPlayer(makePlayer({ started: true, dead: true }));
        render(<SiteHeader />);

        const soundButton = screen.getByRole('button', { name: /Sound FX/i });
        expect(soundButton).toBeInTheDocument();
        const link = screen.getByRole('link');
        expect(link).not.toContainElement(soundButton);
    });

    it('keeps the SoundToggle outside the clickable <a> when the header IS clickable', () => {
        setPlayer(makePlayer({ started: true, ambushed: false, dead: false }));
        render(<SiteHeader />);

        const link = screen.getByRole('link');
        const soundButton = screen.getByRole('button', { name: /Sound FX/i });
        expect(link.contains(soundButton)).toBe(false);
    });

    // Regression: clicking the header from a pre-character screen (The Tome of Lore, Chronicles
    // of Ancestry, Hall of Champions) used to fire `player:screen`, which the server rejects with
    // NOT_STARTED — surfacing as `player:screen = error` in the backend log on an action the
    // player experienced as working fine.
    it('navigates home without reporting a screen when no character exists yet', () => {
        useGameStore.setState({ screen: 'statistics' }, false);
        setPlayer(makePlayer({ started: false, name: null }));
        render(<SiteHeader />);
        requestMock.mockClear();

        fireEvent.click(screen.getByRole('link'));

        expect(useGameStore.getState().screen).toBe('start');
        expect(requestMock).not.toHaveBeenCalled();
    });

    it('still reports the screen when a character does exist', () => {
        useGameStore.setState({ screen: 'statistics' }, false);
        setPlayer(makePlayer({ started: true, dead: false, ambushed: false }));
        render(<SiteHeader />);
        requestMock.mockClear();

        fireEvent.click(screen.getByRole('link'));

        expect(useGameStore.getState().screen).toBe('home');
        expect(requestMock).toHaveBeenCalledWith('player:screen', { screen: 'home' });
    });
});
