import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen } from '@testing-library/react';
import { useGameStore } from '@/store/gameStore';
import ErrorBoundary from '@/components/ErrorBoundary';

function Bomb(): never {
    throw new Error('Kaboom from a render');
}

describe('ErrorBoundary', () => {
    beforeEach(() => {
        useGameStore.setState({ catalog: null }, false);
    });

    it('renders children normally when nothing throws', () => {
        render(
            <ErrorBoundary>
                <div>All good</div>
            </ErrorBoundary>,
        );
        expect(screen.getByText('All good')).toBeInTheDocument();
    });

    it('shows the caught error message as detail in a non-release build (catalog.isRelease === false)', () => {
        useGameStore.setState({ catalog: { isRelease: false } as any }, false);
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

    it('never leaks the raw error message in a release build (catalog.isRelease === true) — regression guard, the old app only ever showed this in dev', () => {
        useGameStore.setState({ catalog: { isRelease: true } as any }, false);
        const consoleErrorSpy = vi.spyOn(console, 'error').mockImplementation(() => {});

        render(
            <ErrorBoundary>
                <Bomb />
            </ErrorBoundary>,
        );

        expect(screen.getByText(/An unexpected error occurred on the server/)).toBeInTheDocument();
        expect(screen.queryByText('Kaboom from a render')).not.toBeInTheDocument();
        expect(document.querySelector('.code-block')).not.toBeInTheDocument();

        consoleErrorSpy.mockRestore();
    });

    it('defaults to hiding the detail when catalog has not loaded yet (fail closed)', () => {
        const consoleErrorSpy = vi.spyOn(console, 'error').mockImplementation(() => {});

        render(
            <ErrorBoundary>
                <Bomb />
            </ErrorBoundary>,
        );

        expect(screen.queryByText('Kaboom from a render')).not.toBeInTheDocument();

        consoleErrorSpy.mockRestore();
    });
});
