import { useEffect, useRef, useState } from 'react';
import type { PlayerSnapshot } from '@shared/contract';
import { formatNumber } from '@shared/format';
import { useAnimatedNumber } from '@/hooks/useAnimatedNumber';
import { useShimmer } from '@/hooks/useShimmer';

interface HpBarProps {
    player: PlayerSnapshot;
}

// Ported from partials/status.ejs's HP stat-row. The bar-FILL percentage animates purely via the
// `.bar` CSS `transition: width 600ms cubic-bezier(...)` rule already in components.css — no JS
// ever computes an intermediate width, since the browser's own compositor does that more
// cheaply and smoothly than a per-frame React re-render would. `useAnimatedNumber` only drives
// the numeric HP text, which is the one part of this row users actually read digit-by-digit.
export default function HpBar({ player }: HpBarProps) {
    const health = player.health ?? 0;
    const { display } = useAnimatedNumber(health, { format: formatNumber });

    // Shimmer fires ONLY on an HP *increase* — mirrors sidebar.js's
    // `if (targetHp > startHp) triggerBarShimmer(hpBar)` and socket.js's updateHealth's
    // `if (newHp > prevHp) { ...shimmer... }`. A damage tick never shimmers.
    const prevHealthRef = useRef(health);
    const [gainTick, setGainTick] = useState(0);
    useEffect(() => {
        if (health > prevHealthRef.current)
            setGainTick(t => t + 1);
        prevHealthRef.current = health;
    }, [health]);
    const shimmer = useShimmer(gainTick);

    return (
        <div className={`stat-row bar${player.lowHealth ? ' danger' : ''}`}>
            <span className="stat-label">HP</span>
            <div className="bar-track" id="hp-track">
                <div
                    className={`bar hp-bar${shimmer ? ' shimmer-active' : ''}`}
                    id="hp-bar"
                    style={{ width: `${player.hpPercent}%` }}
                />
                <span className="bar-text">
                    <span className="animate-val">{display}</span>
                    /<span id="status-max-hp">{formatNumber(player.maxHealth ?? 0)}</span>
                </span>
            </div>
        </div>
    );
}
