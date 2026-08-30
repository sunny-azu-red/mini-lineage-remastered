import { describe, it, expect, beforeEach } from 'vitest';
import { render, screen, fireEvent } from '@testing-library/react';
import type { PlayerSnapshot } from '@shared/contract';
import { useGameStore, type ScreenId } from '@/store/gameStore';
import LowHealthAlert from '@/components/common/LowHealthAlert';
import { makePlayer } from '../../factories';

// The defaults this file's assertions were written against.
const localPlayer = (o: Partial<Parameters<typeof makePlayer>[0]> = {}) =>
    makePlayer({ health: 10, hpPercent: 10, lowHealth: true, ...o });

function resetStore(screen: ScreenId, player: PlayerSnapshot | null) {
    useGameStore.setState(
        {
            status: 'ready',
            player,
            catalog: null,
            screen,
            highscoreRaceFilter: null,
            flash: null,
            lastBattle: null,
            notice: null,
            soundEnabled: false,
        },
        false,
    );
}

describe('LowHealthAlert', () => {
    beforeEach(() => {
        resetStore('home', localPlayer());
    });

    it('renders nothing when the player is not low on health', () => {
        resetStore('home', localPlayer({ lowHealth: false }));
        const { container } = render(<LowHealthAlert />);
        expect(container).toBeEmptyDOMElement();
    });

    it('renders nothing for a dead player, even if flagged lowHealth', () => {
        resetStore('home', localPlayer({ lowHealth: true, dead: true }));
        const { container } = render(<LowHealthAlert />);
        expect(container).toBeEmptyDOMElement();
    });

    it('renders nothing when there is no player at all', () => {
        resetStore('home', null);
        const { container } = render(<LowHealthAlert />);
        expect(container).toBeEmptyDOMElement();
    });

    it('shows the plain, Inn-linking message when low on health and not ambushed', () => {
        resetStore('home', localPlayer({ lowHealth: true, ambushed: false }));
        render(<LowHealthAlert />);
        expect(screen.getByText(/dangerously low/)).toBeInTheDocument();
        expect(screen.getByRole('link', { name: 'Inn' })).toBeInTheDocument();
    });

    it('shows the ambush-flavored message when low on health and ambushed', () => {
        resetStore('home', localPlayer({ lowHealth: true, ambushed: true }));
        render(<LowHealthAlert />);
        expect(screen.getByText(/dangerously low/)).toBeInTheDocument();
        expect(screen.getByText(/Your warm blood stains/)).toBeInTheDocument();
        expect(screen.queryByRole('link', { name: 'Inn' })).not.toBeInTheDocument();
    });

    it('clicking the Inn link navigates to the Inn screen', () => {
        resetStore('home', localPlayer({ lowHealth: true, ambushed: false }));
        render(<LowHealthAlert />);
        fireEvent.click(screen.getByRole('link', { name: 'Inn' }));
        expect(useGameStore.getState().screen).toBe('inn');
    });

    it('is suppressed on the Suicide screen (matching the old hideLowHealthAlert option)', () => {
        resetStore('suicide', localPlayer({ lowHealth: true, ambushed: false }));
        const { container } = render(<LowHealthAlert />);
        expect(container).toBeEmptyDOMElement();
    });

    it('is suppressed on the Inn screen itself (its own message links there)', () => {
        resetStore('inn', localPlayer({ lowHealth: true, ambushed: false }));
        const { container } = render(<LowHealthAlert />);
        expect(container).toBeEmptyDOMElement();
    });
});
