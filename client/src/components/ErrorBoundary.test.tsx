import { describe, it, expect, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import ErrorBoundary from './ErrorBoundary';

function Bomb(): never {
    throw new Error('Kaboom from a render');
}

describe('ErrorBoundary', () => {
    it('renders children normally when nothing throws', () => {
        render(
            <ErrorBoundary>
                <div>All good</div>
            </ErrorBoundary>,
        );
        expect(screen.getByText('All good')).toBeInTheDocument();
    });

    it('catches a render-time throw and renders ErrorScreen with the error message as detail instead of crashing', () => {
        // React logs the caught error to console.error too (on top of our own componentDidCatch
        // log) — silence it so the test output stays clean; not asserting on it either way.
        const consoleErrorSpy = vi.spyOn(console, 'error').mockImplementation(() => {});

        render(
            <ErrorBoundary>
                <Bomb />
            </ErrorBoundary>,
        );

        expect(screen.getByText(/An unexpected error occurred on the server/)).toBeInTheDocument();
        expect(screen.getByText('Kaboom from a render').tagName).toBe('PRE');

        consoleErrorSpy.mockRestore();
    });
});
