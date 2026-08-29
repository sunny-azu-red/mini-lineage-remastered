import { useEffect, useRef, useState } from 'react';
import type { PlayerSnapshot } from '@shared/contract';
import { formatNumber } from '@shared/format';
import { useAnimatedNumber } from '@/hooks/useAnimatedNumber';
import { useShimmer } from '@/hooks/useShimmer';

interface XpBarProps {
    player: PlayerSnapshot;
}

// A tiny child component so `key={levelUpEpoch}` (see below) can force a full remount on every
// level-up, resetting useAnimatedNumber's internal "first value" ref. On a level-up remount,
// this starts the freshly-mounted hook instance at 0 (its own "first value, show instantly, no
// sweep" case) and then retargets it to the real `value` one frame later — which IS a normal
// (non-first) retarget, so useAnimatedNumber eases upward from 0 to `value` exactly like the old
// game's sidebar.js did (`startXp = isLevelUp ? 0 : lastXp`, then `animateValue(el, startXp,
// targetXp, ...)`). `resetConsumedRef` limits that one-frame deferral to just this initial reset
// — every LATER value change during this same mounted instance's lifetime (a normal xp gain
// within the level) sets the target immediately, exactly like before a level-up ever happened.
function AnimatedXpValue({ value, justLeveledUp }: { value: number; justLeveledUp: boolean }) {
    const [target, setTarget] = useState(justLeveledUp ? 0 : value);
    const resetConsumedRef = useRef(!justLeveledUp);

    useEffect(() => {
        if (resetConsumedRef.current) {
            setTarget(value);
            return;
        }

        resetConsumedRef.current = true;
        const rafId = requestAnimationFrame(() => setTarget(value));
        return () => cancelAnimationFrame(rafId);
        // eslint-disable-next-line react-hooks/exhaustive-deps
    }, [value]);

    const { display } = useAnimatedNumber(target, { format: formatNumber });
    return <>{display}</>;
}

// Ported from partials/status.ejs's XP stat-row.
export default function XpBar({ player }: XpBarProps) {
    const pct = player.isMaxLevel ? 100 : player.xpPercent;
    const xpValue = player.isMaxLevel ? (player.experience ?? 0) : player.xpCurrent;

    // Mirrors sidebar.js's level-up special case (`isLevelUp = lastLevel > 0 && targetLevel >
    // lastLevel`, `startXp = isLevelUp ? 0 : lastXp`, `startXpPct = isLevelUp ? 0 : lastXpPct`).
    // xpCurrent legitimately *decreases* across a level-up (it wraps to the remainder into the
    // new level) — without this check that reads as a "loss" and would neither shimmer nor look
    // right. A level-up always counts as a gain, and always plays the same two-phase animation
    // sidebar.js used: (a) snap the bar to 0% with its CSS transition disabled for one frame (the
    // in-memory equivalent of sidebar.js's `xpBar.style.transition = 'none'` + forced-reflow
    // reset, with no sessionStorage involved), (b) one frame later, restore the transition and
    // fall back to the real post-level-up percentage, so it animates a smooth fill from 0 —
    // instead of jumping straight there with no animation, or animating backwards through the
    // wrap-around gap (e.g. 95% -> 5%). The counter (`AnimatedXpValue`, remounted via `key`) gets
    // the identical treatment for the same reason.
    const prevLevelRef = useRef(player.level);
    const prevXpRef = useRef(xpValue);
    const [levelUpEpoch, setLevelUpEpoch] = useState(0);
    const [suppressBarTransition, setSuppressBarTransition] = useState(false);
    // Non-null only during the one-frame level-up reset window (forces width to 0%); null the
    // rest of the time, when the bar just tracks `pct` directly.
    const [levelUpBarPct, setLevelUpBarPct] = useState<number | null>(null);
    const [gainTick, setGainTick] = useState(0);
    // Persisted (not recomputed per-render like `isLevelUp` below) specifically so it's still
    // true on the render where `levelUpEpoch` actually changes and `AnimatedXpValue` remounts —
    // that happens one render AFTER `isLevelUp` was true, by which point `prevLevelRef.current`
    // has already caught up to `player.level` and `isLevelUp` itself has gone back to false.
    const [justLeveledUp, setJustLeveledUp] = useState(false);

    const isLevelUp = prevLevelRef.current !== null && player.level !== null && player.level > prevLevelRef.current;

    useEffect(() => {
        if (isLevelUp) {
            setLevelUpEpoch(e => e + 1);
            setSuppressBarTransition(true);
            setLevelUpBarPct(0);
            setJustLeveledUp(true);
        }
        if (isLevelUp || xpValue > prevXpRef.current)
            setGainTick(t => t + 1);

        prevLevelRef.current = player.level;
        prevXpRef.current = xpValue;
        // eslint-disable-next-line react-hooks/exhaustive-deps
    }, [player.level, xpValue, isLevelUp]);

    // Deliberately its OWN effect, keyed only on `suppressBarTransition` — NOT folded into the
    // level-up-detection effect above. That effect's dependency array also includes `xpValue`,
    // so if another xp-changing render landed before this rAF fired, its cleanup would cancel
    // the reset with nothing left to ever set `suppressBarTransition` back to `false` — silently
    // and permanently disabling the bar's width transition for the rest of the session. Keying
    // this reset on `suppressBarTransition` itself means only a change to THIS flag can cancel
    // a pending reset, never an unrelated xp update. Releasing `levelUpBarPct` back to `null` in
    // the same batch lets the bar fall through to the real `pct` right as the transition
    // re-enables, which is what animates the fill from 0 up to it.
    useEffect(() => {
        if (!suppressBarTransition)
            return;

        const rafId = requestAnimationFrame(() => {
            setSuppressBarTransition(false);
            setLevelUpBarPct(null);
        });
        return () => cancelAnimationFrame(rafId);
    }, [suppressBarTransition]);

    const shimmer = useShimmer(gainTick);
    const displayPct = levelUpBarPct ?? pct;

    return (
        <div className="stat-row bar">
            <span className="stat-label">XP</span>
            <div className="bar-track">
                <div
                    className={`bar xp-bar${shimmer ? ' shimmer-active' : ''}`}
                    id="xp-bar"
                    style={{ width: `${displayPct}%`, transition: suppressBarTransition ? 'none' : undefined }}
                    data-level={player.level ?? undefined}
                />
                <span className="bar-text">
                    <span className="animate-val">
                        <AnimatedXpValue key={levelUpEpoch} value={xpValue} justLeveledUp={justLeveledUp} />
                    </span>
                    {!player.isMaxLevel && <>/{formatNumber(player.xpRequired)}</>}
                </span>
            </div>
        </div>
    );
}
