import type { MouseEvent } from 'react';
import { useGameStore } from '@/store/gameStore';
import { SIDEBAR_SCREENS } from '../layout/AppShell';

// One representative line lifted from the old nine-line random pool. The randomness is flavor
// text, not game state, so unlike the battle narrative it needn't go through the contract.
const AMBUSH_LOW_HEALTH_LINE = 'Your warm blood stains the ancient, cold earth of Aden...';

// Shown whenever lowHealth && !dead, on any screen that shows HP. Suppressed on Suicide and the
// Inn itself, whose own call to action already is "go to the Inn".
export default function LowHealthAlert() {
    const player = useGameStore(state => state.player);
    const screen = useGameStore(state => state.screen);
    const navigate = useGameStore(state => state.navigate);

    if (!player?.lowHealth || player.dead || !SIDEBAR_SCREENS.has(screen) || screen === 'suicide' || screen === 'inn')
        return null;

    function handleInnClick(e: MouseEvent<HTMLAnchorElement>) {
        e.preventDefault();
        navigate('inn');
    }

    return (
        <div id="low-health-alert" className="alert alert-danger">
            Your HP is dangerously low!<br />
            {player.ambushed ? AMBUSH_LOW_HEALTH_LINE : (
                <>You should buy some food from the 🍺 <a href="#inn" onClick={handleInnClick}>Inn</a> to regain your strength.</>
            )}
        </div>
    );
}
