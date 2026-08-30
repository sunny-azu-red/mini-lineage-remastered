import { useEffect, useRef, useState } from 'react';
import type { PlayerSnapshot } from '@shared/contract';
import { formatNumber } from '@shared/format';
import { useAnimatedNumber } from '@/hooks/useAnimatedNumber';
import { useShimmer } from '@/hooks/useShimmer';

/**
 * A separate component purely so `key={levelUpEpoch}` can force a remount on every level-up,
 * resetting useAnimatedNumber's internal "first value" ref. On that remount it starts at 0 (the
 * hook's show-instantly case) and is retargeted to the real value one frame later — a normal,
 * non-first retarget, so the hook eases 0 -> value. `resetConsumedRef` limits that one-frame
 * deferral to the initial reset; every later change within the same mounted instance retargets
 * immediately, exactly as before any level-up.
 */
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

export default function XpBar({ player }: { player: PlayerSnapshot }) {
    const pct = player.isMaxLevel ? 100 : player.xpPercent;
    const xpValue = player.isMaxLevel ? (player.experience ?? 0) : player.xpCurrent;

    const prevLevelRef = useRef(player.level);
    const prevXpRef = useRef(xpValue);
    const [levelUpEpoch, setLevelUpEpoch] = useState(0);
    // One flag for the whole one-frame reset window: it both forces the bar to 0% and disables
    // its CSS width transition. These always moved together, so they are a single state.
    const [resettingBar, setResettingBar] = useState(false);
    const [gainTick, setGainTick] = useState(0);
    // Persisted rather than recomputed, so it is still true on the render where `levelUpEpoch`
    // changes and AnimatedXpValue remounts — one render AFTER `isLevelUp` was true, by which
    // point prevLevelRef has caught up and `isLevelUp` is false again.
    const [justLeveledUp, setJustLeveledUp] = useState(false);

    const isLevelUp = prevLevelRef.current !== null && player.level !== null && player.level > prevLevelRef.current;

    /**
     * xpCurrent legitimately DECREASES across a level-up (it wraps into the new level), which
     * would otherwise read as a loss. A level-up always counts as a gain and always plays the
     * two-phase animation: snap to 0% with the transition off for one frame, then restore both so
     * the bar fills smoothly from 0 — instead of jumping with no animation, or animating
     * backwards through the wrap-around gap (95% -> 5%). The counter gets the same treatment via
     * the remount above.
     */
    useEffect(() => {
        if (isLevelUp) {
            setLevelUpEpoch(epoch => epoch + 1);
            setResettingBar(true);
            setJustLeveledUp(true);
        }
        if (isLevelUp || xpValue > prevXpRef.current)
            setGainTick(tick => tick + 1);

        prevLevelRef.current = player.level;
        prevXpRef.current = xpValue;
        // eslint-disable-next-line react-hooks/exhaustive-deps
    }, [player.level, xpValue, isLevelUp]);

    // Deliberately its OWN effect, keyed only on `resettingBar` — NOT folded into the one above,
    // whose deps include `xpValue`. If another xp-changing render landed before this rAF fired,
    // that effect's cleanup would cancel the reset with nothing left to clear the flag, silently
    // disabling the bar's transition for the rest of the session.
    useEffect(() => {
        if (!resettingBar)
            return;

        const rafId = requestAnimationFrame(() => setResettingBar(false));
        return () => cancelAnimationFrame(rafId);
    }, [resettingBar]);

    const shimmer = useShimmer(gainTick);

    return (
        <div className="stat-row bar">
            <span className="stat-label">XP</span>
            <div className="bar-track">
                <div
                    className={`bar xp-bar${shimmer ? ' shimmer-active' : ''}`}
                    id="xp-bar"
                    style={{ width: `${resettingBar ? 0 : pct}%`, transition: resettingBar ? 'none' : undefined }}
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
