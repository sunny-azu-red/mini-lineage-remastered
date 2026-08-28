import type { PlayerSnapshot } from '@shared/contract';
import { formatAdena } from '@shared/format';
import { useAnimatedNumber } from '@/hooks/useAnimatedNumber';

interface AdenaRowProps {
    player: PlayerSnapshot;
}

// Ported from partials/status.ejs. No shimmer here — matching the original, adena counters were
// never wired to `triggerBarShimmer` in sidebar.js/socket.js (only the HP/XP bars were).
export default function AdenaRow({ player }: AdenaRowProps) {
    const { display } = useAnimatedNumber(player.adena ?? 0, { format: formatAdena });

    return (
        <div className="stat-row">
            <span className="stat-label">Adena</span>
            <span className="stat-value gold">
                🪙 <span className="animate-adena">{display}</span>
            </span>
        </div>
    );
}
