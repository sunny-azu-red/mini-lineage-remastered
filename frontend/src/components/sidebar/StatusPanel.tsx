import { useGameStore } from '@/store/gameStore';
import { formatNumber } from '@shared/format';
import HpBar from './HpBar';
import XpBar from './XpBar';
import AdenaRow from './AdenaRow';

// Ported from partials/status.ejs. The old EJS baked a pre-rendered `levelDisplay` HTML string
// server-side (emoji + race/level, as a link to /character unless ambushed/dead); reconstructed
// here from plain PlayerSnapshot fields since the client owns rendering now. That whole gate is
// gone: the store's `navigate()` unconditionally pins the screen to 'battle' whenever ambushed,
// or to 'death' whenever dead, so this link can always attempt to navigate to Character and
// simply gets redirected either way — it no longer needs to know or care about either state.
export default function StatusPanel() {
    const player = useGameStore(state => state.player);
    const navigate = useGameStore(state => state.navigate);

    if (!player)
        return null;

    const statusEmoji = player.dead ? '☠️' : (player.raceEmoji ?? '');
    const levelText = `${player.raceLabel ?? ''} level ${formatNumber(player.level ?? 0)}`;

    return (
        <div className="panel status-panel">
            <div className="panel-header flex">
                <span className="header-name">{player.name}</span>
            </div>
            <div className="panel-body small">
                <div className="stat-row">
                    <span className="stat-label">Race</span>
                    <span className="stat-value">
                        {statusEmoji}{' '}
                        <a
                            href="#character"
                            onClick={e => {
                                e.preventDefault();
                                navigate('character');
                            }}
                        >
                            {levelText}
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
