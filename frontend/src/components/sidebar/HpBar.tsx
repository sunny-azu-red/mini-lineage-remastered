import { useEffect, useRef, useState } from 'react';
import type { PlayerSnapshot } from '@shared/contract';
import { formatNumber } from '@shared/format';
import { useAnimatedNumber } from '@/hooks/useAnimatedNumber';
import { useShimmer } from '@/hooks/useShimmer';

// The bar FILL animates via the CSS width transition (cheaper than a per-frame re-render);
// useAnimatedNumber drives only the numeric text.
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
