import { useGameStore } from '@/store/gameStore';
import { useBattleFight } from '@/socket/useBattleFight';
import Narrative from './Narrative';

const FALLBACK_AMBUSH_LINE = 'You are being ambushed!';

/**
 * Renders on EVERY screen (wired into AppShell, same structural slot a LowHealthAlert would use)
 * whenever `player.ambushed`. Plan decision A6/the client-side "Ambush UX" section: the player
 * can still browse read-only screens while ambushed, but the ONLY way to resolve the ambush —
 * from here or from the Battle screen itself — is this same explicit "Fight!" click. There is no
 * time limit, no penalty for leaving it up, and no auto-resolution on navigation/reload.
 *
 * Narrative text comes from `lastBattle.narrative.ambushLine`, populated either by the most
 * recent `battle:fight` ack (`recordBattleResult`) OR — Fix 4 — by `hydrate()` from the
 * server-persisted `PlayerSnapshot.lastBattle`, so it's reliably present even right after a
 * fresh page load/reconnect for any player who has fought at least once. The `FALLBACK_AMBUSH_LINE`
 * below is now a true last resort: it only renders for a character that has never fought at all
 * (fresh from Game Start, immediately ambushed) — everything else gets the real, server-rolled
 * ambush line.
 *
 * Suppressed on the Battle screen itself: BattleScreen renders this exact same
 * narrative+Fight-button treatment inline (see its own "ambushed" branch, matching
 * battleground.ejs precisely) — rendering both here AND there would duplicate the alert/button.
 */
export default function AmbushBanner() {
    const player = useGameStore(state => state.player);
    const lastBattle = useGameStore(state => state.lastBattle);
    const navigate = useGameStore(state => state.navigate);
    const screen = useGameStore(state => state.screen);
    const { fight, pending } = useBattleFight();

    if (!player?.ambushed || screen === 'battle')
        return null;

    const ambushLine = lastBattle?.narrative.ambushLine ?? FALLBACK_AMBUSH_LINE;
    const fightPrompt = lastBattle?.narrative.fightPrompt ?? 'Fight!';

    // Battle simulation ONLY ever happens on this explicit click — never on mount, hydrate, or
    // reconnect. This is the entire anti-cheat redesign; do not add an effect that calls
    // battle:fight automatically.
    function handleFight() {
        if (screen !== 'battle')
            navigate('battle');
        fight();
    }

    return (
        <div className="alert alert-danger">
            💢 <Narrative html={ambushLine} />
            <div className="action-links">
                <button type="button" className="btn btn-danger" disabled={pending} onClick={handleFight}>
                    ⚔️ {fightPrompt}
                </button>
            </div>
        </div>
    );
}
