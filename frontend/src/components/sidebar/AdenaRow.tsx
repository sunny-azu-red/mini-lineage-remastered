import type { PlayerSnapshot } from '@shared/contract';
import { formatAdena } from '@shared/format';
import { useAnimatedNumber } from '@/hooks/useAnimatedNumber';

// No shimmer here — matching the original, only the HP/XP bars were ever wired to one.
export default function AdenaRow({ player }: { player: PlayerSnapshot }) {
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
