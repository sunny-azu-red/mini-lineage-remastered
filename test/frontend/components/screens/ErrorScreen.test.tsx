import { describe, it, expect, vi } from 'vitest';
import { render, screen, fireEvent } from '@testing-library/react';
import ErrorScreen from '@/components/screens/ErrorScreen';

describe('ErrorScreen', () => {
    it('renders the generic message with no detail block when detail is omitted', () => {
        render(<ErrorScreen />);
        expect(screen.getByText(/An unexpected error occurred on the server/)).toBeInTheDocument();
        expect(document.querySelector('.code-block')).not.toBeInTheDocument();
    });

    it('renders the detail in a code block when provided', () => {
        render(<ErrorScreen detail="Something exploded" />);
        expect(screen.getByText('Something exploded').tagName).toBe('PRE');
    });

    it('the back link calls window.history.back() (ported .js-back-link behavior)', () => {
        const backSpy = vi.spyOn(window.history, 'back').mockImplementation(() => {});
        render(<ErrorScreen />);

        fireEvent.click(screen.getByRole('link', { name: /Return to safer lands/ }));

        expect(backSpy).toHaveBeenCalledTimes(1);
        backSpy.mockRestore();
    });
});
