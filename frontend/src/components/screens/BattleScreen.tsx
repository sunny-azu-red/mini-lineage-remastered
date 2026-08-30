import { useEffect, type MouseEvent } from 'react';
import type { BattleNarrative } from '@shared/contract';
import { useGameStore } from '@/store/gameStore';
import { useBattleFight } from '@/socket/useBattleFight';
import Narrative from '@/components/common/Narrative';

const FALLBACK_AMBUSH_LINE = 'You are being ambushed!';

/**
 * Whenever a battle result exists the narrative paragraphs ALWAYS render first; `ambushed` only
 * branches what appears below them, never whether they appear.
 *
 * The "never fought yet" state has no old-app equivalent — loading /battle used to simulate a
 * fight as a side effect, which is exactly the bug this rewrite exists to delete. So a
 * genuinely-never-fought character gets an un-narrated prompt instead. A reload no longer hits
 * that path: hydrate repopulates `lastBattle` from the server-persisted snapshot.
 */
export default function BattleScreen() {
    const player = useGameStore(state => state.player);
    const lastBattle = useGameStore(state => state.lastBattle);
    const navigate = useGameStore(state => state.navigate);
    const { fight, pending } = useBattleFight();

    // Reacts to an ack that already happened; it never triggers one. `lastBattle.died` alone is
    // not enough — it can be stale from a previous life — so it must agree with `player.dead`,
    // which the same ack set.
    useEffect(() => {
        if (lastBattle?.died && player?.dead)
            navigate('death');
    }, [lastBattle, player?.dead, navigate]);

    if (!player || player.dead)
        return null;

    function handleRetreat(e: MouseEvent<HTMLAnchorElement>) {
        e.preventDefault();
        navigate('home');
    }

    // Battle simulation happens ONLY on this explicit click — never on mount, hydrate or
    // reconnect. That is the entire anti-cheat redesign; never add an effect that calls fight().
    const fightButton = (label: string, danger: boolean) => (
        <button type="button" className={danger ? 'btn btn-danger' : 'btn'} disabled={pending} onClick={fight}>
            {label}
        </button>
    );
    const retreatLink = <a href="#home" className="btn btn-secondary" onClick={handleRetreat}>Retreat</a>;

    const narrative = lastBattle?.narrative;

    if (player.ambushed) {
        return (
            <>
                {narrative && <BattleNarrativeBlock narrative={narrative} />}
                <div className="alert alert-danger">
                    💢 <Narrative html={narrative?.ambushLine ?? FALLBACK_AMBUSH_LINE} />
                </div>
                <div className="action-links">{fightButton(`⚔️ ${narrative?.fightPrompt ?? 'Fight!'}`, true)}</div>
            </>
        );
    }

    return (
        <>
            {narrative
                ? <BattleNarrativeBlock narrative={narrative} />
                : <p>The road out of town is quiet for now. Will you seek out a fight?</p>}
            <div className="action-links">
                {fightButton(narrative ? `⚡ ${narrative.nextMove}` : '⚔️ Fight!', false)}
                {retreatLink}
            </div>
        </>
    );
}

function BattleNarrativeBlock({ narrative }: { narrative: BattleNarrative }) {
    return (
        <>
            <p>
                {narrative.critLine && <><Narrative html={narrative.critLine} /> </>}
                <Narrative html={narrative.killLine} /> <Narrative html={narrative.deflectionLine} />
            </p>
            <p><Narrative html={narrative.outcomeLine} /></p>
        </>
    );
}
