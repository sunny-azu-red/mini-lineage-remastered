import { describe, it, expect } from 'vitest';
import { render } from '@testing-library/react';
import type { EffectView } from '@shared/contract';
import EffectIcon from '@/components/effects/EffectIcon';

const NOW = 1_700_000_000_000;

function makeEffect(overrides: Partial<EffectView> = {}): EffectView {
    return {
        id: 'e1',
        type: 'buff',
        emoji: '💪',
        label: 'Strength',
        tooltip: 'Strength (+5 Attack)',
        ...overrides,
    };
}

function renderIcon(effect: EffectView, now: number = NOW): HTMLElement {
    const { container } = render(<EffectIcon effect={effect} now={now} />);
    return container.querySelector('.effect-icon') as HTMLElement;
}

describe('EffectIcon', () => {
    it.each(['buff', 'debuff', 'aura'] as const)('applies the effect-%s modifier class alongside the base classes', type => {
        const icon = renderIcon(makeEffect({ type }));

        expect(icon.className).toBe(`effect-icon effect-fade-in effect-${type}`);
    });

    // Defensive: `type` is non-optional in the contract, but renderEffects()'s original markup
    // simply omitted the modifier class whenever it was absent — keep that behavior.
    it('omits the type modifier class entirely when the effect carries no type', () => {
        const icon = renderIcon(makeEffect({ type: '' as unknown as EffectView['type'] }));

        expect(icon.className).toBe('effect-icon effect-fade-in');
    });

    it('carries the data attributes and tooltip title the ported markup/CSS depend on', () => {
        const icon = renderIcon(makeEffect({ id: 'combat', label: 'In Combat', tooltip: 'In Combat (no regen)', expiresAt: NOW + 30_000 }));

        expect(icon).toHaveAttribute('data-effect-id', 'combat');
        expect(icon).toHaveAttribute('data-label', 'In Combat');
        expect(icon).toHaveAttribute('data-expires-at', String(NOW + 30_000));
        expect(icon).toHaveAttribute('title', 'In Combat (no regen)');
    });

    it('renders the emoji in its own span', () => {
        const icon = renderIcon(makeEffect({ emoji: '🛡️' }));

        expect(icon.querySelector('.effect-emoji')?.textContent).toBe('🛡️');
    });

    it('renders no data-expires-at attribute and no timer at all for an effect without expiresAt', () => {
        const icon = renderIcon(makeEffect({ expiresAt: undefined }));

        expect(icon).not.toHaveAttribute('data-expires-at');
        expect(icon.querySelector('.effect-timer')).toBeNull();
    });

    // formatEffectTimer: >= 60s collapses to whole minutes, below that it's a bare second count.
    it('renders the remaining time through formatEffectTimer — 90s away reads as "1m"', () => {
        const icon = renderIcon(makeEffect({ expiresAt: NOW + 90_000 }));

        expect(icon.querySelector('.effect-timer')?.textContent).toBe('1m');
    });

    it('renders a bare second count under a minute — 45s away reads as "45"', () => {
        const icon = renderIcon(makeEffect({ expiresAt: NOW + 45_000 }));

        expect(icon.querySelector('.effect-timer')?.textContent).toBe('45');
    });

    it('clamps an already-expired effect to "0" rather than counting negative', () => {
        const icon = renderIcon(makeEffect({ expiresAt: NOW - 5_000 }));

        expect(icon.querySelector('.effect-timer')?.textContent).toBe('0');
    });
});
