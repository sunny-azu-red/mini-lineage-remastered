import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen } from '@testing-library/react';
import type { PlayerSnapshot } from '@shared/contract';
import { useGameStore, type ScreenId } from '@/store/gameStore';
import { makeCatalog, makePlayer } from '../../factories';

// navigate() always calls .then() on this now (to apply the player:screen ack to its own
// store) — needs a resolved default so tests that don't care about the response don't crash.
vi.mock('@/socket/client', () => ({
    request: vi.fn().mockResolvedValue({ ok: false, error: { code: 'INTERNAL', message: 'mock default' } }),
}));

const { default: AppShell } = await import('@/components/layout/AppShell');

function setStore(screenId: ScreenId, player: PlayerSnapshot | null) {
    useGameStore.setState(
        {
            status: 'ready',
            player,
            catalog: makeCatalog(),
            screen: screenId,
            highscoreRaceFilter: null,
            flash: null,
            lastBattle: null,
            notice: null,
            soundEnabled: false,
        },
        false,
    );
}

describe('AppShell', () => {
    beforeEach(() => {
        vi.clearAllMocks();
    });

    it.each<ScreenId>(['home', 'battle', 'weapons', 'armors', 'inn', 'suicide', 'death'])(
        'shows the sidebar on screen "%s" once the player has started',
        screenId => {
            setStore(screenId, makePlayer());
            render(<AppShell title="Home Town"><div /></AppShell>);
            expect(document.getElementById('sidebar')).not.toBeNull();
        },
    );

    it.each<ScreenId>(['start', 'character', 'highscores', 'statistics', 'races', 'error'])(
        'hides the sidebar on screen "%s" even once the player has started',
        screenId => {
            setStore(screenId, makePlayer());
            render(<AppShell title="Home Town"><div /></AppShell>);
            expect(document.getElementById('sidebar')).toBeNull();
        },
    );

    it('hides the sidebar on the pre-game Game Start screen (player exists but has not started)', () => {
        setStore('start', makePlayer({ started: false }));
        render(<AppShell title="Home Town"><div /></AppShell>);
        expect(document.getElementById('sidebar')).toBeNull();
    });

    it('hides the sidebar on an allowlisted screen when the player has not started (e.g. right after Death -> Play Again resets in place)', () => {
        setStore('home', makePlayer({ started: false }));
        render(<AppShell title="Home Town"><div /></AppShell>);
        expect(document.getElementById('sidebar')).toBeNull();
    });

    it('hides the sidebar when there is no player at all', () => {
        setStore('home', null);
        render(<AppShell title="Home Town"><div /></AppShell>);
        expect(document.getElementById('sidebar')).toBeNull();
    });

    it('renders the children passed to it', () => {
        setStore('home', makePlayer());
        render(<AppShell title="Home Town"><div data-testid="child-content">hello</div></AppShell>);
        expect(screen.getByTestId('child-content')).toBeInTheDocument();
    });

    it('renders the title prop as the in-panel heading, replacing the old hardcoded "Mini Lineage" literal', () => {
        setStore('battle', makePlayer());
        render(<AppShell title="Battleground"><div /></AppShell>);
        expect(screen.getByText('Battleground')).toBeInTheDocument();
    });

    // Pre-hydrate window (bootstrap fetch + socket handshake still in flight): every screen
    // component guards on `!catalog` itself, so gating once here is what stops the panel from
    // rendering as a blank, broken-looking page.
    describe('before the first hydrate lands (catalog still null)', () => {
        beforeEach(() => {
            setStore('home', makePlayer());
            useGameStore.setState({ catalog: null }, false);
        });

        it('shows a "Loading" heading instead of the real screen title', () => {
            render(<AppShell title="Home Town"><div /></AppShell>);

            expect(screen.getByText('Loading')).toBeInTheDocument();
            expect(screen.queryByText('Home Town')).not.toBeInTheDocument();
        });

        it('shows the LoadingPanel instead of the screen children', () => {
            const { container } = render(<AppShell title="Home Town"><div data-testid="child-content">hello</div></AppShell>);

            expect(container.querySelector('.loading-panel')).not.toBeNull();
            expect(screen.getByText('Entering the realm…')).toBeInTheDocument();
            expect(screen.queryByTestId('child-content')).not.toBeInTheDocument();
        });

        it('swaps straight back to the real title and children once catalog arrives', () => {
            const { rerender, container } = render(<AppShell title="Home Town"><div data-testid="child-content">hello</div></AppShell>);
            expect(container.querySelector('.loading-panel')).not.toBeNull();

            setStore('home', makePlayer());
            rerender(<AppShell title="Home Town"><div data-testid="child-content">hello</div></AppShell>);

            expect(container.querySelector('.loading-panel')).toBeNull();
            expect(screen.getByText('Home Town')).toBeInTheDocument();
            expect(screen.getByTestId('child-content')).toBeInTheDocument();
        });
    });
});
