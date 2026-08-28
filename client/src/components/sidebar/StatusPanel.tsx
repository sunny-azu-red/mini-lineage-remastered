import { useGameStore } from '@/store/gameStore';
import { formatNumber } from '@shared/format';
import HpBar from './HpBar';
import XpBar from './XpBar';
import AdenaRow from './AdenaRow';

// Ported from partials/status.ejs. The old EJS baked a pre-rendered `levelDisplay` HTML string
// server-side (emoji + race/level, as a link to /character unless ambushed/dead); reconstructed
// here from plain PlayerSnapshot fields since the client owns rendering now. The ambush half of
// that no longer applies: the store's `navigate()` unconditionally pins the screen to 'battle'
// whenever `player.ambushed`, so this link can always attempt to navigate to Character while
// ambushed and simply gets redirected. `dead` is unrelated and still gates clickability. The link
// becomes a `navigate('character')` call once routing exists — for this task it's a plain button
// when clickable, matching only visual/semantic intent, not full click-through behavior yet.
export default function StatusPanel() {
    const player = useGameStore(state => state.player);
    const navigate = useGameStore(state => state.navigate);

    if (!player)
        return null;

    const statusEmoji = player.dead ? '☠️' : (player.raceEmoji ?? '');
    const isClickable = !player.dead;
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
                        {isClickable ? (
                            <a
                                href="#character"
                                onClick={e => {
                                    e.preventDefault();
                                    navigate('character');
                                }}
                            >
                                {levelText}
                            </a>
                        ) : (
                            <span className="gold">{levelText}</span>
                        )}
                    </span>
                </div>
                <HpBar player={player} />
                <XpBar player={player} />
                <AdenaRow player={player} />
            </div>
        </div>
    );
}
