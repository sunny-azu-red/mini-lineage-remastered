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
        useGameStore.setState({ effectsStampedAt: NOW });
    });

    it('renders nothing at all for an empty effects array', () => {
        const { container } = render(<EffectsList effects={[]} />);

        expect(container).toBeEmptyDOMElement();
    });

    it('renders one icon per effect, in order', () => {
        const { container } = render(
            <EffectsList
                effects={[
                    makeEffect({ id: 'a', emoji: '💪', remainingMs: 60_000 }),
                    makeEffect({ id: 'b', emoji: '🛡️', type: 'debuff', remainingMs: 30_000 }),
                    makeEffect({ id: 'c', emoji: '⚔️', type: 'aura' }),
                ]}
            />,
        );

        const icons = Array.from(container.querySelectorAll('.effect-icon'));
        expect(icons).toHaveLength(3);
        expect(icons.map(el => el.getAttribute('data-effect-id'))).toEqual(['a', 'b', 'c']);
    });

    it('passes the shared `now` down, so each icon renders a timer relative to it', () => {
        const { container } = render(<EffectsList effects={[makeEffect({ remainingMs: 45_000 })]} />);

        expect(container.querySelector('.effect-timer')?.textContent).toBe('45');
    });

    /**
     * The rule, for every effect type: the SERVER withdraws effects, the client never does.
     *
     * `buildPlayerSnapshot` derives both `effects[]` and `stats` from `getActiveEffects`, so a
     * snapshot already excludes anything expired and is internally consistent. Hiding an effect
     * here early only ever disagreed with it — and took the icon away while the max HP that same
     * buff was granting stayed put until the next push.
     */
    it('keeps every effect the server sent, past its deadline or not, showing 0', () => {
        const { container } = render(
            <EffectsList
                effects={[
                    makeEffect({ id: 'staleBuff', remainingMs: -1 }),
                    makeEffect({ id: 'combat', type: 'aura', emoji: '⚔️', remainingMs: -1 }),
                    makeEffect({ id: 'live', remainingMs: 10_000 }),
                ]}
            />,
        );

        const icons = Array.from(container.querySelectorAll('.effect-icon'));
        expect(icons.map(el => el.getAttribute('data-effect-id'))).toEqual(['staleBuff', 'combat', 'live']);
        expect(container.querySelector('[data-effect-id="staleBuff"] .effect-timer')?.textContent).toBe('0');
        expect(container.querySelector('[data-effect-id="live"] .effect-timer')?.textContent).toBe('10');
    });

    /**
     * `expiresAt` is stamped by the SERVER, so counting it down against this machine's clock let
     * any skew between the two shift every timer — a server 3s ahead made a 5-second effect read 8.
     * syncClock() measures that offset and the countdown is read against server time instead.
     */
    /**
     * FLAW 3, pinned. `Math.ceil` on a server DEADLINE minus a local clock read showed 6 for a
     * 5-second aura whenever the difference came out even a millisecond over 5000 — and a
     * cross-machine difference can err either way, so no amount of clock-sync precision removed it.
     *
     * A duration counted against elapsed local time cannot do that: `remainingMs` is at most the
     * effect's real length and `elapsed` is at least zero, so the displayed value is at most the
     * effect's length in seconds. There is no arithmetic path to 6.
     */
    describe('a 5-second effect can never display 6', () => {
        it('opens on 5 at the instant it arrives', () => {
            const { container } = render(<EffectsList effects={[makeEffect({ id: 'combat', type: 'aura', remainingMs: 5_000 })]} />);

            expect(container.querySelector('.effect-timer')?.textContent).toBe('5');
        });

        it('stays at 5 or below however the stamp and the clock line up', () => {
            // Every elapsed value the store can produce, plus a negative one — a stamp momentarily
            // ahead of the clock, which a clock adjustment could produce. None may read 6.
            for (const stampOffset of [-50, -1, 0, 1, 250, 999]) {
                useGameStore.setState({ effectsStampedAt: NOW + stampOffset });
                const { container, unmount } = render(
                    <EffectsList effects={[makeEffect({ id: 'combat', type: 'aura', remainingMs: 5_000 })]} />,
                );

                expect(Number(container.querySelector('.effect-timer')?.textContent)).toBeLessThanOrEqual(5);
                unmount();
            }
        });

        it('counts all the way down to 0 and no further', () => {
            const { container } = render(<EffectsList effects={[makeEffect({ id: 'combat', type: 'aura', remainingMs: 2_000 })]} />);

            expect(container.querySelector('.effect-timer')?.textContent).toBe('2');

            act(() => {
                vi.advanceTimersByTime(1_000);
            });
            expect(container.querySelector('.effect-timer')?.textContent).toBe('1');

            act(() => {
                vi.advanceTimersByTime(5_000); // well past it
            });
            expect(container.querySelector('.effect-timer')?.textContent).toBe('0');
        });
    });

    it('keeps a permanent effect (no remainingMs) forever', () => {
        const { container } = render(<EffectsList effects={[makeEffect({ id: 'aura', type: 'aura', remainingMs: undefined })]} />);

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

        rerender(<EffectsList effects={[makeEffect({ id: 'combat', type: 'aura', remainingMs: 5_000 })]} />);

        expect(container.querySelector('.effect-timer')?.textContent).toBe('5');
    });

    /**
     * The same staleness at the other end of the countdown. A render landing between interval
     * firings — a background tick pushing new player state, say — must measure the real clock. A
     * stale sample kept a already-expired buff on screen still reading "1", which is why an effect
     * appeared to vanish "with a second left" the moment the server's own push finally arrived.
     */
    it('reads 0 for a passed deadline, even on a render the interval did not cause', () => {
        const effects = [makeEffect({ id: 'food', remainingMs: 2_500 })];
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

        expect(container.querySelector('.effect-timer')?.textContent).toBe('0');
    });

    // Regression: without the shared countdown tick re-rendering this list, an expiring buff's
    // timer would freeze at "0" and the icon would linger until the next state:update push —
    // the "buffs don't disappear correctly" symptom.
    it('runs each countdown down to 0 as the shared tick advances `now`', () => {
        const { container } = render(
            <EffectsList
                effects={[
                    makeEffect({ id: 'short', remainingMs: 2_000 }),
                    makeEffect({ id: 'long', remainingMs: 120_000 }),
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

        // Both remain — withdrawing them is the server's call — but the lapsed one reads 0.
        expect(container.querySelector('[data-effect-id="short"] .effect-timer')?.textContent).toBe('0');
        expect(container.querySelector('[data-effect-id="long"] .effect-timer')?.textContent).toBe('1m'); // formatEffectTimer renders minutes above 60s
    });
});
