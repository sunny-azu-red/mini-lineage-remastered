import { describe, it, expect, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import { useGameStore } from '@/store/gameStore';
import Footer from '@/components/layout/Footer';
import { makeCatalog } from '../../factories';

describe('Footer', () => {
    it('renders a link to the tagged commit when commitUrl is set (release build)', () => {
        useGameStore.setState(
            { catalog: makeCatalog({ isRelease: true, commitUrl: 'https://github.com/example/repo/commit/abc1234', version: 'abc1234' }) },
            false,
        );

        render(<Footer />);

        const link = screen.getByRole('link', { name: 'abc1234' });
        expect(link).toHaveAttribute('href', 'https://github.com/example/repo/commit/abc1234');
        expect(link).toHaveAttribute('target', '_blank');
        expect(link).toHaveClass('version-link');
    });

    it('renders plain text (no link) when commitUrl is null (debug build)', () => {
        useGameStore.setState(
            { catalog: makeCatalog({ isRelease: false, commitUrl: null, version: '⚡ development' }) },
            false,
        );

        render(<Footer />);

        expect(screen.queryByRole('link')).not.toBeInTheDocument();
        const versionSpan = screen.getByText('⚡ development');
        expect(versionSpan).toHaveClass('version-debug');
    });

    it('renders nothing version-related before catalog has hydrated', () => {
        useGameStore.setState({ catalog: null }, false);

        render(<Footer />);

        expect(screen.queryByRole('link')).not.toBeInTheDocument();
        expect(screen.queryByText('version-debug')).not.toBeInTheDocument();
    });

    // The gap this closes: with no catalog — still connecting, or the backend is unreachable —
    // the footer used to show only "© 2005 – 2026", so there was no way to tell which build was
    // loaded at exactly the moment that matters most for diagnosing an outage.
    it('names the build from its own compile-time constant when the catalog has not arrived', () => {
        useGameStore.setState({ catalog: null }, false);
        const { container } = render(<Footer />);

        expect(container.textContent).toContain('⚡ development');
        // A dev build genuinely IS a debug build, so the warning colour is correct here.
        expect(container.querySelector('.version-debug')).toBeInTheDocument();
    });

    // Regression: `.version-debug` is the red "this is a debug build" marker. It used to be
    // applied whenever the catalog had not arrived, so a production bundle flagged ITSELF as a
    // debug build for the whole loading window, then silently corrected once the server answered.
    it('does not flag a release-shaped version as a debug build while loading', () => {
        vi.stubGlobal('__APP_VERSION__', 'a1b2c3d');
        useGameStore.setState({ catalog: null }, false);
        const { container } = render(<Footer />);

        expect(container.textContent).toContain('a1b2c3d');
        expect(container.querySelector('.version-debug')).not.toBeInTheDocument();
        vi.unstubAllGlobals();
    });

    it('still flags a non-release version as a debug build while loading', () => {
        vi.stubGlobal('__APP_VERSION__', 'unknown');
        useGameStore.setState({ catalog: null }, false);
        const { container } = render(<Footer />);

        expect(container.querySelector('.version-debug')).toBeInTheDocument();
        vi.unstubAllGlobals();
    });

    it('prefers the server version once the catalog lands', () => {
        useGameStore.setState({ catalog: makeCatalog({ version: 'abc1234', commitUrl: null }) }, false);
        const { container } = render(<Footer />);

        expect(container.textContent).toContain('abc1234');
        expect(container.textContent).not.toContain('⚡ development');
    });
});
