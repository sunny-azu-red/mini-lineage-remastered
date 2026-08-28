import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, fireEvent } from '@testing-library/react';
import { useGameStore } from '@/store/gameStore';
import ErrorScreen from '@/components/screens/ErrorScreen';

describe('ErrorScreen', () => {
    beforeEach(() => {
        useGameStore.setState({ player: null, screen: 'error' }, false);
    });

    it('renders the generic message with no detail block when detail is omitted', () => {
        render(<ErrorScreen />);
        expect(screen.getByText(/An unexpected error occurred on the server/)).toBeInTheDocument();
        expect(document.querySelector('.code-block')).not.toBeInTheDocument();
    });

    it('renders the detail in a code block when provided', () => {
        render(<ErrorScreen detail="Something exploded" />);
        expect(screen.getByText('Something exploded').tagName).toBe('PRE');
    });

    it('the back link calls window.history.back() when there is history to go back to (ported .js-back-link behavior)', () => {
        vi.spyOn(window.history, 'length', 'get').mockReturnValue(2);
        const backSpy = vi.spyOn(window.history, 'back').mockImplementation(() => {});
        render(<ErrorScreen />);

        fireEvent.click(screen.getByRole('link', { name: /Return to safer lands/ }));

        expect(backSpy).toHaveBeenCalledTimes(1);
        vi.restoreAllMocks();
    });

    it('falls back to navigating home/start (no reload) when there is no history to go back to — the old app hard-redirected to "/" here', () => {
        vi.spyOn(window.history, 'length', 'get').mockReturnValue(1);
        const backSpy = vi.spyOn(window.history, 'back').mockImplementation(() => {});
        useGameStore.setState({ player: { started: true } as any }, false);

        render(<ErrorScreen />);
        fireEvent.click(screen.getByRole('link', { name: /Return to safer lands/ }));

        expect(backSpy).not.toHaveBeenCalled();
        expect(useGameStore.getState().screen).toBe('home');
        vi.restoreAllMocks();
    });
});
