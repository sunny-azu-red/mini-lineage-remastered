import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, renderHook, screen as rtl, waitFor } from '@testing-library/react';
import type { ScreenId } from '@shared/contract';

const { socketEmitMock, requestMock } = vi.hoisted(() => ({
    socketEmitMock: vi.fn(),
    requestMock: vi.fn(),
}));
vi.mock('@/socket/client', () => ({ request: requestMock, socket: { emit: socketEmitMock } }));

const { useGameStore } = await import('@/store/gameStore');
const { usePanelFocus } = await import('@/hooks/usePanelFocus');
const { default: App } = await import('@/App');
const { makePlayer, makeCatalog } = await import('../factories');

/**
 * Keyboard-first play: the panel's first control takes focus on its own, so the game is playable
 * without a mouse — Space repeats the Fight button, ↑↓ + Enter drives the travel/shop selects.
 *
 * jsdom does NOT blur a focused element when it becomes disabled, unlike every real browser
 * (verified directly). Tests that care about the disable/enable cycle therefore have to call
 * `.blur()` themselves; without that they would pass with the hook removed and prove nothing.
 */

const CATALOG = makeCatalog({
    races: [{ id: 0, label: 'Human', plural: 'Humans', emoji: '🧙', slug: 'human', enemyRaceId: 1, startHealth: 100, startAdena: 300, ambushChance: 8, regen: 1, crit: 4, backstory: 'b', traits: 't' }],
    weapons: [{ id: 0, name: 'Fists', emoji: '👊', stat: 7, cost: 0 }, { id: 1, name: 'Needle', emoji: '🗡️', stat: 16, cost: 300 }],
    armors: [{ id: 0, name: 'Tunic', emoji: '🧥', stat: 2, cost: 0 }, { id: 1, name: 'Leathers', emoji: '🥋', stat: 10, cost: 500 }],
    foods: [{ id: 0, name: 'Ale', emoji: '🍺', stat: 4, cost: 7 }],
});

const EQUIPPED = {
    weapon: { id: 0, name: 'Fists', emoji: '👊', stat: 7, cost: 0 },
    armor: { id: 0, name: 'Tunic', emoji: '🧥', stat: 2, cost: 0 },
    stats: { attack: 7, defense: 2, crit: 4, regen: 1, ambushRisk: 8 },
    raceId: 0,
} as const;

const ALIVE = { ...EQUIPPED, started: true, dead: false, ambushed: false };

/** Renders the whole app on `screen`, so the panel, alerts and screens are the real ones. */
function renderOn(screen: ScreenId, player: Partial<Parameters<typeof makePlayer>[0]> = ALIVE) {
    useGameStore.setState({ player: makePlayer(player), catalog: CATALOG, screen }, false);

    return render(<App />);
}

beforeEach(() => {
    requestMock.mockReset();
    requestMock.mockResolvedValue({ ok: false, error: { code: 'INTERNAL', message: 'mock' } });
    window.history.replaceState(null, '', '/');
    document.body.focus();
    useGameStore.setState(
        { status: 'ready', player: null, catalog: null, screen: 'start', highscoreRaceFilter: null, flash: null, lastBattle: null, notice: null, soundEnabled: false },
        false,
    );
});

describe('usePanelFocus', () => {
    it('focuses the Fight button on the battleground, so Space fights straight away', () => {
        renderOn('battle');

        expect(rtl.getByRole('button', { name: /Fight/ })).toHaveFocus();
    });

    it('focuses the destination select on Home, not its Travel button', () => {
        const { container } = renderOn('home');

        expect(container.querySelector('.panel-body select')).toHaveFocus();
        expect(rtl.getByRole('button', { name: 'Travel' })).not.toHaveFocus();
    });

    it('focuses the name field on the start screen, ahead of the race select and button', () => {
        const { container } = renderOn('start', { started: false, name: null });

        expect(container.querySelector('.panel-body input')).toHaveFocus();
    });

    /**
     * The one screen that must stay untouched. You arrive by dying — plausibly with a Space press
     * already travelling — and both of its buttons are consequential: one submits the highscore
     * before the death message has been read, the other restarts and skips submission entirely.
     */
    it('focuses nothing at all on the death screen', () => {
        renderOn('death', { ...EQUIPPED, started: true, dead: true, deathReason: 'You fell.', highscoreEligible: true });

        expect(rtl.getByRole('button', { name: /Play Again/ })).not.toHaveFocus();
        expect(rtl.getByRole('button', { name: /Legacy/ })).not.toHaveFocus();
        expect(document.body).toHaveFocus();
    });

    // NoticeAlert renders its dismiss × inside .panel-body BEFORE the screen's own content, so a
    // naive "first button in the panel" would arm Space to dismiss the banner instead of playing.
    it('skips the notice banner dismiss button and still focuses the screen control', () => {
        useGameStore.setState({ notice: { code: 'INTERNAL', message: 'Something broke.' } }, false);
        const { container } = renderOn('battle');

        expect(container.querySelector('.alert-dismiss')).not.toHaveFocus();
        expect(rtl.getByRole('button', { name: /Fight/ })).toHaveFocus();
    });

    it('does not steal focus from a control the player moved to themselves', async () => {
        const { container } = renderOn('home');

        const button = rtl.getByRole('button', { name: 'Travel' });
        button.focus();
        expect(button).toHaveFocus();

        // Any in-screen mutation — a background tick landing, say — must leave that alone.
        useGameStore.getState().setNotice({ code: 'INTERNAL', message: 'A tick landed.' });

        await waitFor(() => expect(container.querySelector('.alert')).not.toBeNull());
        expect(button).toHaveFocus();
    });

    it('moves focus into the panel on a screen change, even out of a header link', async () => {
        renderOn('home');

        const headerLink = rtl.getAllByRole('link')[0];
        headerLink.focus();
        expect(headerLink).toHaveFocus();

        useGameStore.getState().navigate('battle');

        await waitFor(() => expect(rtl.getByRole('button', { name: /Fight/ })).toHaveFocus());
    });

    /**
     * The core regression, and the reason establishing focus once is not enough. useAction
     * disables the button for the length of its request; a real browser blurs it to <body>, so by
     * the time the ack re-enables it, focus is gone and the next Space would scroll the page.
     */
    it('restores focus to the Fight button after the request disables and re-enables it', async () => {
        renderOn('battle');

        const button = rtl.getByRole('button', { name: /Fight/ });
        expect(button).toHaveFocus();

        // Reproduces what a browser does when a focused element becomes disabled. jsdom does not
        // do it, so it is done by hand — otherwise this test would pass with the hook removed.
        // Blur BEFORE disabling: jsdom's blur() no-ops on an element that is already disabled,
        // which would leave it focused and quietly invert the test.
        button.blur();
        (button as HTMLButtonElement).disabled = true;
        expect(document.body).toHaveFocus();

        (button as HTMLButtonElement).disabled = false;

        await waitFor(() => expect(button).toHaveFocus());
    });

    it('leaves a disabled control alone rather than arming Space on the next button along', async () => {
        const { container } = renderOn('battle');

        const button = rtl.getByRole('button', { name: /Fight/ }) as HTMLButtonElement;
        button.blur();          // before disabling — see the note in the test above
        button.disabled = true;

        // Force the observer to run while the real target is unavailable.
        useGameStore.getState().setNotice({ code: 'INTERNAL', message: 'In flight.' });
        await waitFor(() => expect(container.querySelector('.alert-dismiss')).not.toBeNull());

        expect(document.body).toHaveFocus();
        expect(container.querySelector('.alert-dismiss')).not.toHaveFocus();
    });

    // ErrorBoundary renders <ErrorScreen> bare, replacing AppShell and its panel entirely.
    it('does nothing when there is no panel to search', () => {
        expect(() => renderHook(() => usePanelFocus('battle'))).not.toThrow();
        expect(document.body).toHaveFocus();
    });
});
