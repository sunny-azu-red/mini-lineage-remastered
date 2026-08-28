import type { MouseEvent } from 'react';
import { useGameStore } from '@/store/gameStore';
import { SIDEBAR_SCREENS } from '../layout/AppShell';

// Old app's AMBUSH_LOW_HEALTH_MESSAGES (src/constant/narratives.constant.ts) was a nine-line
// random pool. That randomness is flavor text, not game state, so — unlike the battle
// narrative fix — there's no need to plumb it through the contract; one representative line
// (lifted verbatim from that pool) is an acceptable simplification.
const AMBUSH_LOW_HEALTH_LINE = 'Your warm blood stains the ancient, cold earth of Aden...';

/**
 * Ported from layout.view.ts's old `lowHealthAlert` logic: shown whenever
 * `player.lowHealth && !player.dead`, with an ambush-flavored line while `player.ambushed`
 * (matching AMBUSH_LOW_HEALTH_MESSAGES's tone), or a plain line linking to the Inn otherwise.
 *
 * Suppressed on the Suicide screen — the old app's `hideLowHealthAlert` option, used by
 * `renderSuicideView` (see git show 6256e28:src/view/player.view.ts). The old app ALSO suppressed
 * it on the Inn screen itself (`renderInnView`, same mechanism) — reproduced here too, since the
 * plain variant's own call-to-action is "go to the Inn", which is nonsensical to show while
 * already standing in it.
 *
 * Also gated on `SIDEBAR_SCREENS` (the same allowlist AppShell uses to decide whether the status
 * panel/HP bar is even on screen) — there's no point telling the player their HP is low on a
 * screen that doesn't show HP at all (Character, Highscores, Statistics, Races, Game Start).
 */
export default function LowHealthAlert() {
    const player = useGameStore(state => state.player);
    const screen = useGameStore(state => state.screen);
    const navigate = useGameStore(state => state.navigate);

    if (!player || !player.lowHealth || player.dead || !SIDEBAR_SCREENS.has(screen) || screen === 'suicide' || screen === 'inn')
        return null;

    function handleInnClick(e: MouseEvent<HTMLAnchorElement>) {
        e.preventDefault();
        navigate('inn');
    }

    return (
        <div id="low-health-alert" className="alert alert-danger">
            {player.ambushed ? (
                <>Your HP is dangerously low!<br />{AMBUSH_LOW_HEALTH_LINE}</>
            ) : (
                <>
                    Your HP is dangerously low!<br />
                    You should buy some food from the 🍺 <a href="#inn" onClick={handleInnClick}>Inn</a> to regain your strength.
                </>
            )}
        </div>
    );
}
