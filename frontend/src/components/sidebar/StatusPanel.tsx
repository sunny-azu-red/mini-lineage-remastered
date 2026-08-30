import type { MouseEvent } from 'react';
import { useGameStore } from '@/store/gameStore';
import { formatNumber } from '@shared/format';
import HpBar from './HpBar';
import XpBar from './XpBar';
import AdenaRow from './AdenaRow';

// The old EJS baked a pre-rendered level line server-side, gated on ambushed/dead. That gate is
// gone: navigate() pins the screen either way, so this link can always attempt Character.
export default function StatusPanel() {
    const player = useGameStore(state => state.player);
    const navigate = useGameStore(state => state.navigate);

    if (!player)
        return null;

    function handleClick(e: MouseEvent<HTMLAnchorElement>) {
        e.preventDefault();
        navigate('character');
    }

    return (
        <div className="panel status-panel">
            <div className="panel-header flex">
                <span className="header-name">{player.name}</span>
            </div>
            <div className="panel-body small">
                <div className="stat-row">
                    <span className="stat-label">Race</span>
                    <span className="stat-value">
                        {player.dead ? '☠️' : (player.raceEmoji ?? '')}{' '}
                        <a href="#character" onClick={handleClick}>
                            {`${player.raceLabel ?? ''} level ${formatNumber(player.level ?? 0)}`}
                        </a>
                    </span>
                </div>
                <HpBar player={player} />
                <XpBar player={player} />
                <AdenaRow player={player} />
            </div>
        </div>
    );
}
