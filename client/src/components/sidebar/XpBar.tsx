import { useEffect, useRef, useState } from 'react';
import type { PlayerSnapshot } from '@shared/contract';
import { formatNumber } from '@shared/format';
import { useAnimatedNumber } from '@/hooks/useAnimatedNumber';
import { useShimmer } from '@/hooks/useShimmer';

interface XpBarProps {
    player: PlayerSnapshot;
}

// A tiny child component so `key={levelUpEpoch}` (see below) can force a full remount of just
// the animated counter, resetting useAnimatedNumber's internal "first value" ref.
function AnimatedXpValue({ value }: { value: number }) {
    const { display } = useAnimatedNumber(value, { format: formatNumber });
    return <>{display}</>;
}

// Ported from partials/status.ejs's XP stat-row.
export default function XpBar({ player }: XpBarProps) {
    const pct = player.isMaxLevel ? 100 : player.xpPercent;
    const xpValue = player.isMaxLevel ? (player.experience ?? 0) : player.xpCurrent;

    // Mirrors sidebar.js's level-up special case (`isLevelUp = lastLevel > 0 && targetLevel >
    // lastLevel`, `startXp = isLevelUp ? 0 : lastXp`). xpCurrent legitimately *decreases* across
    // a level-up (it wraps to the remainder into the new level) — without this check that reads
    // as a "loss" and would neither shimmer nor look right. A level-up always counts as a gain:
    // it (a) always shimmers regardless of the raw number's direction, and (b) remounts the
    // animated counter via `key` so it snaps straight to the post-level-up value instead of
    // sweeping backwards through the wrap-around gap, and (c) briefly suppresses the bar's CSS
    // width transition for one frame so the fill also snaps instead of visibly shrinking before
    // refilling — the in-memory, single-session equivalent of sidebar.js's
    // `xpBar.style.transition = 'none'` + forced-reflow reset, with no sessionStorage involved.
    const prevLevelRef = useRef(player.level);
    const prevXpRef = useRef(xpValue);
    const [levelUpEpoch, setLevelUpEpoch] = useState(0);
    const [suppressBarTransition, setSuppressBarTransition] = useState(false);
    const [gainTick, setGainTick] = useState(0);

    const isLevelUp = prevLevelRef.current !== null && player.level !== null && player.level > prevLevelRef.current;

    useEffect(() => {
        let rafId: number | null = null;

        if (isLevelUp) {
            setLevelUpEpoch(e => e + 1);
            setSuppressBarTransition(true);
            rafId = requestAnimationFrame(() => setSuppressBarTransition(false));
        }
        if (isLevelUp || xpValue > prevXpRef.current)
            setGainTick(t => t + 1);

        prevLevelRef.current = player.level;
        prevXpRef.current = xpValue;

        return () => {
            if (rafId !== null)
                cancelAnimationFrame(rafId);
        };
        // eslint-disable-next-line react-hooks/exhaustive-deps
    }, [player.level, xpValue, isLevelUp]);

    const shimmer = useShimmer(gainTick);

    return (
        <div className="stat-row bar">
            <span className="stat-label">XP</span>
            <div className="bar-track">
                <div
                    className={`bar xp-bar${shimmer ? ' shimmer-active' : ''}`}
                    id="xp-bar"
                    style={{ width: `${pct}%`, transition: suppressBarTransition ? 'none' : undefined }}
                    data-level={player.level ?? undefined}
                />
                <span className="bar-text">
                    <span className="animate-val">
                        <AnimatedXpValue key={levelUpEpoch} value={xpValue} />
                    </span>
                    {!player.isMaxLevel && <>/{formatNumber(player.xpRequired)}</>}
                </span>
            </div>
        </div>
    );
}
