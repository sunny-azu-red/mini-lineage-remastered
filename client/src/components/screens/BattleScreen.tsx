import { useEffect, type MouseEvent } from 'react';
import { useGameStore } from '@/store/gameStore';
import { useBattleFight } from '@/socket/useBattleFight';
import Narrative from '@/components/common/Narrative';

const FALLBACK_AMBUSH_LINE = 'You are being ambushed!';

/**
 * Ported from battleground.ejs — see that template for the exact paragraph grouping/markup this
 * mirrors. The one behavior with NO precedent in the old template is the "no lastBattle yet"
 * state (a genuinely never-fought character): the old server always had *something* to render
 * because loading `/battle` simulated a fight as a side effect. That simulate-on-load behavior is
 * exactly the bug this whole rewrite exists to delete (see the plan's "Context" section) — so
 * this screen shows a plain, un-narrated prompt instead until the player actually clicks Fight.
 *
 * `lastBattle` (and the `FALLBACK_AMBUSH_LINE`/"road is quiet" placeholders below) is no longer
 * wiped by a page reload — Fix 4: `hydrate()` repopulates it from the server-persisted
 * `PlayerSnapshot.lastBattle` on every reconnect, not just the acting tab's live ack. The
 * fallbacks now only trigger for a player who has truly never fought yet.
 */
export default function BattleScreen() {
    const player = useGameStore(state => state.player);
    const lastBattle = useGameStore(state => state.lastBattle);
    const navigate = useGameStore(state => state.navigate);
    const { fight, pending } = useBattleFight();

    // Reacts to an ack that already happened — it never triggers one. `lastBattle.died` alone
    // isn't enough: it can be stale from a previous life (lastBattle survives navigation and is
    // never cleared on restart/highscore-submit), so this only fires once `player.dead` — driven
    // by the SAME ack via `recordBattleResult` — agrees. Once a restart resets `player.dead` back
    // to false, a stale `lastBattle.died === true` can no longer re-trigger this.
    useEffect(() => {
        if (lastBattle?.died && player?.dead)
            navigate('death');
    }, [lastBattle, player?.dead, navigate]);

    if (!player || player.dead)
        return null;

    // Battle simulation ONLY ever happens on this explicit click — never on mount, hydrate, or
    // reconnect. This is the entire anti-cheat redesign; do not add an effect that calls
    // battle:fight automatically.
    function handleFight() {
        fight();
    }

    function handleRetreat(e: MouseEvent<HTMLAnchorElement>) {
        e.preventDefault();
        navigate('home');
    }

    if (player.ambushed) {
        const ambushLine = lastBattle?.narrative.ambushLine ?? FALLBACK_AMBUSH_LINE;
        const fightPrompt = lastBattle?.narrative.fightPrompt ?? 'Fight!';

        // Matches battleground.ejs's ambushed branch exactly: no Retreat option.
        return (
            <>
                <div className="alert alert-danger">
                    💢 <Narrative html={ambushLine} />
                </div>
                <div className="action-links">
                    <button type="button" className="btn btn-danger" disabled={pending} onClick={handleFight}>
                        ⚔️ {fightPrompt}
                    </button>
                </div>
            </>
        );
    }

    if (!lastBattle) {
        return (
            <>
                <p>The road out of town is quiet for now. Will you seek out a fight?</p>
                <div className="action-links">
                    <button type="button" className="btn" disabled={pending} onClick={handleFight}>
                        ⚔️ Fight!
                    </button>
                    <a href="#home" className="btn btn-secondary" onClick={handleRetreat}>Retreat</a>
                </div>
            </>
        );
    }

    const { narrative } = lastBattle;

    return (
        <>
            <p>
                {narrative.critLine && <><Narrative html={narrative.critLine} /> </>}
                <Narrative html={narrative.killLine} /> <Narrative html={narrative.deflectionLine} />
            </p>
            <p><Narrative html={narrative.outcomeLine} /></p>

            <div className="action-links">
                <button type="button" className="btn" disabled={pending} onClick={handleFight}>
                    ⚡ {narrative.nextMove}
                </button>
                <a href="#home" className="btn btn-secondary" onClick={handleRetreat}>Retreat</a>
            </div>
        </>
    );
}
