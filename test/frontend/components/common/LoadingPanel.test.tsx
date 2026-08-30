import { describe, it, expect } from 'vitest';
import { render, screen } from '@testing-library/react';
import LoadingPanel from '@/components/common/LoadingPanel';

describe('LoadingPanel', () => {
    it('renders the spinner element the ported CSS animates', () => {
        const { container } = render(<LoadingPanel />);

        expect(container.querySelector('.loading-panel')).not.toBeNull();
        expect(container.querySelector('.loading-spinner')).not.toBeNull();
    });

    it('renders the waiting copy shown during the bootstrap fetch + socket handshake window', () => {
        render(<LoadingPanel />);

        expect(screen.getByText('Entering the realm…')).toBeInTheDocument();
    });

    it('shows a screen-specific label when one is given', () => {
        render(<LoadingPanel label="Consulting the chronicles…" />);

        expect(screen.getByText('Consulting the chronicles…')).toBeInTheDocument();
        expect(screen.queryByText('Entering the realm…')).not.toBeInTheDocument();
    });

    it('still spins with a custom label', () => {
        const { container } = render(<LoadingPanel label="Unsealing the tome…" />);

        expect(container.querySelector('.loading-spinner')).toBeInTheDocument();
    });
});
