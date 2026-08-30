import { useEffect, useRef, useState } from 'react';
import type { PlayerSnapshot } from '@shared/contract';
import { formatNumber } from '@shared/format';
import { useAnimatedNumber } from '@/hooks/useAnimatedNumber';
import { useShimmer } from '@/hooks/useShimmer';

/**
 * The bar FILL animates purely via the `.bar` CSS width transition — the compositor does that
 * more cheaply than a per-frame React re-render would. `useAnimatedNumber` drives only the
 * numeric text, which is the part users actually read digit by digit.
 */
export default function HpBar({ player }: { player: PlayerSnapshot }) {
    const health = player.health ?? 0;
    const { display } = useAnimatedNumber(health, { format: formatNumber });

    // Shimmer fires ONLY on an HP increase; a damage tick never shimmers.
    const prevHealthRef = useRef(health);
    const [gainTick, setGainTick] = useState(0);

    useEffect(() => {
        if (health > prevHealthRef.current)
            setGainTick(tick => tick + 1);

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
