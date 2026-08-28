import { describe, it, expect } from 'vitest';
import { render, screen } from '@testing-library/react';
import type { GameCatalog } from '@shared/contract';
import { useGameStore } from '@/store/gameStore';
import Footer from '@/components/layout/Footer';

function makeCatalog(overrides: Partial<GameCatalog> = {}): GameCatalog {
    return {
        version: '1.5.0',
        isRelease: false,
        commitUrl: null,
        year: 2026,
        locale: 'en-US',
        lowHealthThreshold: 0.2,
        maxLevel: 50,
        nameMinLength: 1,
        nameMaxLength: 20,
        races: [],
        weapons: [],
        armors: [],
        foods: [],
        ...overrides,
    };
}

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
});
