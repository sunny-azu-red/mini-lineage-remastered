import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import { render, act } from '@testing-library/react';
import type { EffectView } from '@shared/contract';
import EffectsList from '@/components/effects/EffectsList';
import { useGameStore } from '@/store/gameStore';

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
        useGameStore.setState({ clockOffsetMs: 0 });
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

    // A zone aura is REPLACED by the server, not removed — ⚔️ In Combat's disengage countdown
    // becomes 💤 Resting. Hiding it the instant it hit zero would punch a hole in the row for the
    // ~30ms until that push lands, showing a state the game never actually has.
    it('keeps an aura past its expiresAt, since the server replaces rather than removes it', () => {
        const { container } = render(
            <EffectsList
                effects={[
                    makeEffect({ id: 'combat', type: 'aura', emoji: '⚔️', expiresAt: NOW - 1 }),
                    makeEffect({ id: 'staleBuff', expiresAt: NOW - 1 }),
                ]}
            />,
        );

        const icons = Array.from(container.querySelectorAll('.effect-icon'));
        expect(icons.map(el => el.getAttribute('data-effect-id'))).toEqual(['combat']);
    });

    /**
     * `expiresAt` is stamped by the SERVER, so counting it down against this machine's clock let
     * any skew between the two shift every timer — a server 3s ahead made a 5-second effect read 8.
     * syncClock() measures that offset and the countdown is read against server time instead.
     */
    describe('with the server clock ahead of the local one', () => {
        const SKEW = 3_000;

        beforeEach(() => {
            useGameStore.setState({ clockOffsetMs: SKEW });
        });

        it('shows a server-stamped effect at its true remaining time, not the skew plus it', () => {
            // What the server would stamp for a 5s effect: its own clock, which reads NOW + SKEW.
            const { container } = render(
                <EffectsList effects={[makeEffect({ id: 'combat', type: 'aura', expiresAt: NOW + SKEW + 5_000 })]} />,
            );

            expect(container.querySelector('.effect-timer')?.textContent).toBe('5');
        });

        it('drops it after its true duration, not the duration plus the skew', () => {
            // A 2-second effect, stamped by a server whose clock reads NOW + SKEW.
            const { container } = render(
                <EffectsList effects={[makeEffect({ id: 'food', expiresAt: NOW + SKEW + 2_000 })]} />,
            );
            expect(container.querySelector('.effect-timer')?.textContent).toBe('2');

            act(() => {
                vi.advanceTimersByTime(1_000);
            });
            expect(container.querySelector('.effect-timer')?.textContent).toBe('1');

            // Two seconds have genuinely passed, so it is over. Compared against local time the
            // deadline would still look SKEW away, leaving the icon up reading 3.
            act(() => {
                vi.advanceTimersByTime(1_000);
            });
            expect(container.querySelector('.effect-icon')).toBeNull();
        });
    });

    it('keeps a permanent effect (no expiresAt) forever', () => {
        const { container } = render(<EffectsList effects={[makeEffect({ id: 'aura', type: 'aura', expiresAt: undefined })]} />);

        act(() => {
            vi.advanceTimersByTime(60_000);
        });

        expect(container.querySelector('.effect-icon')).not.toBeNull();
        expect(container.querySelector('.effect-timer')).toBeNull();
    });

    /**
     * The reported bug: a 5-second aura opened its countdown on 6, sometimes 7.
     *
     * Staleness only exists BETWEEN interval firings, which is why nothing above caught it — every
     * other test advances by whole multiples of the 1000ms interval, so the sampled clock happens
     * to be fresh. Here the clock moves 500ms without the interval firing, and then an effect
     * arrives (as a server push would). Holding `now` in state measured against a timestamp 500ms
     * old and `Math.ceil` rounded the remainder up to 6.
     */
    it('opens a freshly arrived effect on its true duration, not one second more', () => {
        const { container, rerender } = render(<EffectsList effects={[]} />);

        act(() => {
            vi.advanceTimersByTime(500); // clock moves; the 1000ms interval has NOT fired
        });

        rerender(<EffectsList effects={[makeEffect({ id: 'combat', type: 'aura', expiresAt: Date.now() + 5_000 })]} />);

        expect(container.querySelector('.effect-timer')?.textContent).toBe('5');
    });

    /**
     * The same staleness at the other end of the countdown. A render landing between interval
     * firings — a background tick pushing new player state, say — must measure the real clock. A
     * stale sample kept a already-expired buff on screen still reading "1", which is why an effect
     * appeared to vanish "with a second left" the moment the server's own push finally arrived.
     */
    it('drops an effect whose deadline has passed, even on a render the interval did not cause', () => {
        const effects = [makeEffect({ id: 'food', expiresAt: NOW + 2_500 })];
        const { container, rerender } = render(<EffectsList effects={effects} />);

        act(() => {
            vi.advanceTimersByTime(2_000); // interval fires at 1000 and 2000
        });
        expect(container.querySelector('.effect-timer')?.textContent).toBe('1');

        // Past the deadline, but short of the next interval firing at 3000.
        act(() => {
            vi.advanceTimersByTime(600);
        });
        rerender(<EffectsList effects={effects} />);

        expect(container.querySelector('.effect-icon')).toBeNull();
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
