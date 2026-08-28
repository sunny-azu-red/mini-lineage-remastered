import { useEffect, type MouseEvent } from 'react';
import { useGameStore } from '@/store/gameStore';
import { useBattleFight } from '@/socket/useBattleFight';
import Narrative from '@/components/common/Narrative';

const FALLBACK_AMBUSH_LINE = 'You are being ambushed!';

/**
 * Ported from battleground.ejs — see that template for the exact paragraph grouping/markup this
 * mirrors. Per that template, whenever a battle result exists, the narrative paragraphs
 * (crit/kill/deflection lines, then the outcome line) are ALWAYS rendered first, unconditionally —
 * `ambushed` only ever branches what's shown BELOW that narrative (the ambush alert + "Face your
 * Foe!" button vs. the next-move prompt + Retreat), never whether the narrative itself shows.
 *
 * The one behavior with NO precedent in the old template is the "no lastBattle yet" state (a
 * genuinely never-fought character): the old server always had *something* to render because
 * loading `/battle` simulated a fight as a side effect. That simulate-on-load behavior is exactly
 * the bug this whole rewrite exists to delete (see the plan's "Context" section) — so this screen
 * shows a plain, un-narrated prompt instead until the player actually clicks Fight, with its own
 * ambushed sub-case (`FALLBACK_AMBUSH_LINE`) since there's no real narrative to show in that
 * specific edge case.
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

    // Graceful fallback for the genuinely-never-fought edge case: no real narrative exists yet,
    // so there's nothing to show above the action row. Still branches on `ambushed` (a fresh
    // character can be ambushed immediately on their very first ever visit to this screen).
    if (!lastBattle) {
        if (player.ambushed) {
            return (
                <>
                    <div className="alert alert-danger">
                        💢 <Narrative html={FALLBACK_AMBUSH_LINE} />
                    </div>
                    <div className="action-links">
                        <button type="button" className="btn btn-danger" disabled={pending} onClick={handleFight}>
                            ⚔️ Fight!
                        </button>
                    </div>
                </>
            );
        }

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
            {/*
             * Matches battleground.ejs exactly: the narrative paragraphs render unconditionally
             * whenever a battle result exists — `ambushed` only branches what's rendered below
             * them, never whether they render at all.
             */}
            <p>
                {narrative.critLine && <><Narrative html={narrative.critLine} /> </>}
                <Narrative html={narrative.killLine} /> <Narrative html={narrative.deflectionLine} />
            </p>
            <p><Narrative html={narrative.outcomeLine} /></p>

            {player.ambushed ? (
                <>
                    <div className="alert alert-danger">
                        💢 <Narrative html={narrative.ambushLine ?? FALLBACK_AMBUSH_LINE} />
                    </div>
                    <div className="action-links">
                        <button type="button" className="btn btn-danger" disabled={pending} onClick={handleFight}>
                            ⚔️ {narrative.fightPrompt ?? 'Fight!'}
                        </button>
                    </div>
                </>
            ) : (
                <div className="action-links">
                    <button type="button" className="btn" disabled={pending} onClick={handleFight}>
                        ⚡ {narrative.nextMove}
                    </button>
                    <a href="#home" className="btn btn-secondary" onClick={handleRetreat}>Retreat</a>
                </div>
            )}
        </>
    );
}
