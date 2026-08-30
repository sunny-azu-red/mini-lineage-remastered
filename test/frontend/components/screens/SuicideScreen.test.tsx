import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import { useGameStore } from '@/store/gameStore';
import { makePlayer } from '../../factories';

const { requestMock } = vi.hoisted(() => ({ requestMock: vi.fn() }));
vi.mock('@/socket/client', () => ({ request: requestMock }));

const { playSoundMock } = vi.hoisted(() => ({ playSoundMock: vi.fn() }));
vi.mock('@/audio/soundfx', () => ({ playSound: playSoundMock }));

const { default: SuicideScreen } = await import('@/components/screens/SuicideScreen');

function resetStore() {
    useGameStore.setState(
        {
            status: 'ready',
            player: makePlayer(),
            catalog: null,
            screen: 'suicide',
            highscoreRaceFilter: null,
            flash: null,
            lastBattle: null,
            notice: null,
            soundEnabled: false,
        },
        false,
    );
}

describe('SuicideScreen', () => {
    beforeEach(() => {
        requestMock.mockReset();
        // navigate() always calls .then() on this now (to apply the player:screen ack to its
        // own store) — a safe default so tests that don't care about the response don't crash;
        // individual tests below still override it with their own mockResolvedValue.
        requestMock.mockResolvedValue({ ok: false, error: { code: 'INTERNAL', message: 'mock default' } });
        playSoundMock.mockReset();
        resetStore();
    });

    it('loads with "No, I changed my mind" pre-selected and an immediately-clickable Return button, no placeholder option', () => {
        // Mirrors suicide.js exactly: its `change` listener never fired just from the browser
        // default-selecting the first `<option>` on page load, so the button stayed "Return"
        // until the visitor actually touched the dropdown — even though its underlying value
        // was already 'no'.
        render(<SuicideScreen />);

        const select = screen.getByRole('combobox') as HTMLSelectElement;
        expect(select.value).toBe('no');
        expect(screen.queryByText('What will you do?')).not.toBeInTheDocument();

        const button = screen.getByRole('button', { name: 'Return' });
        expect(button).not.toBeDisabled();
        expect(button.className).toBe('btn btn-secondary');
    });

    it('submitting the default Return button (no interaction) still submits the pre-selected "no" and just navigates home', () => {
        render(<SuicideScreen />);

        fireEvent.click(screen.getByRole('button', { name: 'Return' }));

        expect(requestMock).not.toHaveBeenCalledWith('player:suicide', expect.anything());
        expect(useGameStore.getState().screen).toBe('home');
    });

    it('confirming calls player:suicide, applies the mutation, navigates to death, and plays the death sound', async () => {
        const deadPlayer = makePlayer({ dead: true, deathReason: 'You took the cowardly way out.', coward: true });
        requestMock.mockResolvedValue({ ok: true, data: { player: deadPlayer, flash: null } });

        render(<SuicideScreen />);

        fireEvent.change(screen.getByRole('combobox'), { target: { value: 'yes' } });
        fireEvent.click(screen.getByRole('button', { name: 'Do it 🥀' }));

        await waitFor(() => expect(requestMock).toHaveBeenCalledWith('player:suicide', {}));
        await waitFor(() => expect(useGameStore.getState().screen).toBe('death'));

        expect(useGameStore.getState().player).toEqual(deadPlayer);
        expect(playSoundMock).toHaveBeenCalledWith('death');
    });

    it('cancelling navigates home without calling the server', () => {
        render(<SuicideScreen />);

        fireEvent.change(screen.getByRole('combobox'), { target: { value: 'no' } });
        fireEvent.click(screen.getByRole('button', { name: 'Phew 😅' }));

        expect(requestMock).not.toHaveBeenCalledWith('player:suicide', expect.anything());
        expect(playSoundMock).not.toHaveBeenCalled();
        expect(useGameStore.getState().screen).toBe('home');
    });

    // The transition happens in ONE store update against the freshly-dead player. Doing it as
    // navigate()-then-applyMutation would pin 'death' against the still-ALIVE store player,
    // bounce to Home, and report that bogus intermediate screen to the server.
    it('moves to death without bouncing through home', async () => {
        requestMock.mockResolvedValue({ ok: true, data: { player: makePlayer({ dead: true }), flash: null } });
        render(<SuicideScreen />);

        fireEvent.change(screen.getByRole('combobox'), { target: { value: 'yes' } });
        fireEvent.click(screen.getByRole('button', { name: 'Do it 🥀' }));

        await waitFor(() => expect(useGameStore.getState().screen).toBe('death'));
        expect(requestMock).not.toHaveBeenCalledWith('player:screen', { screen: 'home' });
    });
});
