import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, fireEvent } from '@testing-library/react';
import { useGameStore } from '@/store/gameStore';

const { playSoundMock } = vi.hoisted(() => ({ playSoundMock: vi.fn() }));
vi.mock('@/audio/soundfx', () => ({ playSound: playSoundMock }));

const { default: SoundToggle } = await import('@/components/layout/SoundToggle');

describe('SoundToggle', () => {
    beforeEach(() => {
        playSoundMock.mockReset();
    });

    it('unmuting (soundEnabled false -> true) plays the buy chime as audible confirmation', () => {
        useGameStore.setState({ soundEnabled: false }, false);
        render(<SoundToggle />);

        fireEvent.click(screen.getByRole('button'));

        expect(useGameStore.getState().soundEnabled).toBe(true);
        expect(playSoundMock).toHaveBeenCalledWith('buy');
        expect(playSoundMock).toHaveBeenCalledTimes(1);
    });

    it('muting (soundEnabled true -> false) does not play any sound', () => {
        useGameStore.setState({ soundEnabled: true }, false);
        render(<SoundToggle />);

        fireEvent.click(screen.getByRole('button'));

        expect(useGameStore.getState().soundEnabled).toBe(false);
        expect(playSoundMock).not.toHaveBeenCalled();
    });
});
