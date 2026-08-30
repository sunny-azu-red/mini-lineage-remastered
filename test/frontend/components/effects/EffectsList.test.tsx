import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import { render, act } from '@testing-library/react';
import type { EffectView } from '@shared/contract';
import EffectsList from '@/components/effects/EffectsList';

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

describe('EffectsList', () => {
    beforeEach(() => {
        vi.useFakeTimers();
        vi.setSystemTime(NOW);
    });

    afterEach(() => {
        vi.useRealTimers();
    });

    it('renders nothing at all for an empty effects array', () => {
        const { container } = render(<EffectsList effects={[]} />);

        expect(container).toBeEmptyDOMElement();
    });

    it('renders one icon per effect, in order', () => {
        const { container } = render(
            <EffectsList
                effects={[
                    makeEffect({ id: 'a', emoji: '💪', expiresAt: NOW + 60_000 }),
                    makeEffect({ id: 'b', emoji: '🛡️', type: 'debuff', expiresAt: NOW + 30_000 }),
                    makeEffect({ id: 'c', emoji: '⚔️', type: 'aura' }),
                ]}
            />,
        );

        const icons = Array.from(container.querySelectorAll('.effect-icon'));
        expect(icons).toHaveLength(3);
        expect(icons.map(el => el.getAttribute('data-effect-id'))).toEqual(['a', 'b', 'c']);
    });

    it('passes the shared `now` down, so each icon renders a timer relative to it', () => {
        const { container } = render(<EffectsList effects={[makeEffect({ expiresAt: NOW + 45_000 })]} />);

        expect(container.querySelector('.effect-timer')?.textContent).toBe('45');
    });

    // Matches the old EJS rendering, which recomputed getActiveEffects() against Date.now() on
    // every render — an expired buff simply was not in the markup, regardless of whether the
    // server's background sweep had physically removed it yet.
    it('filters out an effect already past its expiresAt, without waiting for a state:update push', () => {
        const { container } = render(
            <EffectsList
                effects={[
                    makeEffect({ id: 'stale', expiresAt: NOW - 1 }),
                    makeEffect({ id: 'live', expiresAt: NOW + 10_000 }),
                ]}
            />,
        );

        const icons = Array.from(container.querySelectorAll('.effect-icon'));
        expect(icons.map(el => el.getAttribute('data-effect-id'))).toEqual(['live']);
    });

    it('keeps a permanent effect (no expiresAt) forever', () => {
        const { container } = render(<EffectsList effects={[makeEffect({ id: 'aura', type: 'aura', expiresAt: undefined })]} />);

        act(() => {
            vi.advanceTimersByTime(60_000);
        });

        expect(container.querySelector('.effect-icon')).not.toBeNull();
        expect(container.querySelector('.effect-timer')).toBeNull();
    });

    // Regression: without the shared countdown tick re-rendering this list, an expiring buff's
    // timer would freeze at "0" and the icon would linger until the next state:update push —
    // the "buffs don't disappear correctly" symptom.
    it('drops an effect the moment its countdown tick carries `now` past its expiresAt', () => {
        const { container } = render(
            <EffectsList
                effects={[
                    makeEffect({ id: 'short', expiresAt: NOW + 2_000 }),
                    makeEffect({ id: 'long', expiresAt: NOW + 120_000 }),
                ]}
            />,
        );

        expect(container.querySelectorAll('.effect-icon')).toHaveLength(2);

        act(() => {
            vi.advanceTimersByTime(1000);
        });
        expect(container.querySelectorAll('.effect-icon')).toHaveLength(2);
        expect(container.querySelector('[data-effect-id="short"] .effect-timer')?.textContent).toBe('1');

        act(() => {
            vi.advanceTimersByTime(2000);
        });

        const remaining = Array.from(container.querySelectorAll('.effect-icon'));
        expect(remaining.map(el => el.getAttribute('data-effect-id'))).toEqual(['long']);
    });
});
