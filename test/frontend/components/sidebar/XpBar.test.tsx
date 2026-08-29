import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import { render, act } from '@testing-library/react';
import type { PlayerSnapshot } from '@shared/contract';
import XpBar from '@/components/sidebar/XpBar';

function stubMatchMedia(matches: boolean) {
    Object.defineProperty(window, 'matchMedia', {
        writable: true,
        configurable: true,
        value: vi.fn().mockImplementation((query: string) => ({
            matches, media: query, onchange: null,
            addListener: vi.fn(), removeListener: vi.fn(),
            addEventListener: vi.fn(), removeEventListener: vi.fn(), dispatchEvent: vi.fn(),
        })),
    });
}

function makePlayer(overrides: Partial<PlayerSnapshot> = {}): PlayerSnapshot {
    return {
        revision: 1, started: true, name: 'Hero', raceId: 1, raceLabel: 'Human', raceEmoji: '🧑',
        health: 80, maxHealth: 100, hpPercent: 80, lowHealth: false,
        experience: 10, level: 2, isMaxLevel: false, xpCurrent: 90, xpRequired: 100, xpPercent: 90, xpNeeded: 10,
        adena: 500, weapon: null, armor: null, stats: null, effects: [],
        dead: false, ambushed: false, coward: false, cheated: false, deathReason: null, highscoreEligible: false,
        counters: { totalBattles: 0, totalAmbushes: 0, consecutiveAmbushes: 0, totalEnemiesKilled: 0 },
        lastBattle: null,
        ...overrides,
    };
}

describe('XpBar', () => {
    beforeEach(() => {
        vi.useFakeTimers();
        stubMatchMedia(false);
    });

    afterEach(() => {
        vi.useRealTimers();
    });

    it('snaps the bar to 0% width with its transition off for the level-up render itself', () => {
        const { rerender, container } = render(<XpBar player={makePlayer({ level: 2, xpCurrent: 90 })} />);

        act(() => {
            rerender(<XpBar player={makePlayer({ level: 3, xpCurrent: 10, xpRequired: 150, xpPercent: 6 })} />);
        });

        const bar = container.querySelector('.xp-bar') as HTMLElement;
        expect(bar.style.transition).toBe('none');
        expect(bar.style.width).toBe('0%');
    });

    // Regression: the bar used to snap straight from the pre-level-up width to the post-level-up
    // width with no animation at all (skipping the 0% stage entirely), matching the reported
    // "the xp bar fills from 0 to some value, that part is not animated" bug. It must now animate
    // a genuine fill from 0% up to the real post-level-up percentage once the transition restores.
    it('animates the bar filling from 0% up to the real percentage once the transition restores', () => {
        const { rerender, container } = render(<XpBar player={makePlayer({ level: 2, xpCurrent: 90 })} />);

        act(() => {
            rerender(<XpBar player={makePlayer({ level: 3, xpCurrent: 10, xpRequired: 150, xpPercent: 6 })} />);
        });
        act(() => {
            vi.advanceTimersByTime(20);
        });

        const bar = container.querySelector('.xp-bar') as HTMLElement;
        expect(bar.style.transition).not.toBe('none');
        // The transition is enabled and the target width is the real 6% — the browser's CSS
        // engine (untestable here) is what actually animates the visible fill from the 0% that
        // was painted on the previous frame up to this new target.
        expect(bar.style.width).toBe('6%');
    });

    // Regression guard: the level-up-detection effect used to schedule the transition's reset
    // via a `requestAnimationFrame` living INSIDE the same effect that watches `xpValue`. If a
    // second xp-changing render landed before that one frame passed, React's cleanup cancelled
    // the pending reset, and nothing else ever set `suppressBarTransition` back to `false` —
    // permanently disabling the bar's width transition for the rest of the session, exactly
    // matching the reported "xp animation stops working after a level-up" bug.
    it('does not permanently disable the bar width transition if another xp change lands before the level-up reset fires', () => {
        const { rerender, container } = render(<XpBar player={makePlayer({ level: 2, xpCurrent: 90 })} />);

        act(() => {
            rerender(<XpBar player={makePlayer({ level: 3, xpCurrent: 10, xpRequired: 150, xpPercent: 6 })} />);
        });

        // A second xp-changing render lands immediately — no time/rAF advanced at all, so the
        // level-up's own pending reset has not fired yet.
        act(() => {
            rerender(<XpBar player={makePlayer({ level: 3, xpCurrent: 60, xpRequired: 150, xpPercent: 40 })} />);
        });

        act(() => {
            vi.advanceTimersByTime(700);
        });

        // A later, unrelated xp gain must still animate normally, not snap forever.
        act(() => {
            rerender(<XpBar player={makePlayer({ level: 3, xpCurrent: 80, xpRequired: 150, xpPercent: 53 })} />);
        });

        const bar = container.querySelector('.xp-bar') as HTMLElement;
        expect(bar.style.transition).not.toBe('none');
    });

    it('animates a normal xp gain that happens after a level-up (not just a snap)', () => {
        const { rerender, getByText } = render(<XpBar player={makePlayer({ level: 2, xpCurrent: 90 })} />);

        act(() => {
            rerender(<XpBar player={makePlayer({ level: 3, xpCurrent: 10, xpRequired: 150, xpPercent: 6 })} />);
        });
        // Two hops of rAF now separate the level-up from the settled value: one frame resets the
        // counter to 0 (AnimatedXpValue's own effect), then a second, freshly-scheduled rAF loop
        // (useAnimatedNumber's) eases it up to 10 — advanced in two separate act()s so React gets
        // a chance to flush the effect that schedules the second hop before more fake time passes
        // (a single big advanceTimersByTime call never "discovers" it).
        act(() => {
            vi.advanceTimersByTime(20);
        });
        act(() => {
            vi.advanceTimersByTime(700);
        });
        expect(getByText('10')).toBeInTheDocument();

        act(() => {
            rerender(<XpBar player={makePlayer({ level: 3, xpCurrent: 60, xpRequired: 150, xpPercent: 40 })} />);
        });
        act(() => {
            vi.advanceTimersByTime(300);
        });

        const midValue = Number(getByText(/^\d+$/).textContent);
        expect(midValue).toBeGreaterThan(10);
        expect(midValue).toBeLessThan(60);

        act(() => {
            vi.advanceTimersByTime(400);
        });
        expect(getByText('60')).toBeInTheDocument();
    });
});
