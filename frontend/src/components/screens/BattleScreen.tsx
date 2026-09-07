import { useEffect, type MouseEvent } from 'react';
import type { BattleNarrative } from '@shared/contract';
import { useGameStore } from '@/store/gameStore';
import { useBattleFight } from '@/socket/useBattleFight';
import { narrativeHtml } from '@/components/common/narrative';

const FALLBACK_AMBUSH_LINE = 'You are being ambushed!';

// Whenever a battle result exists the narrative paragraphs ALWAYS render first; `ambushed` only
// branches what appears below them. A genuinely never-fought character gets an un-narrated prompt
// instead — simulating a fight as a side effect of loading this screen is the bug this rewrite deletes.
export default function BattleScreen() {
    const player = useGameStore(state => state.player);
    const lastBattle = useGameStore(state => state.lastBattle);
    const navigate = useGameStore(state => state.navigate);
    const { fight, pending } = useBattleFight();

    // Reacts to an ack that already happened; never triggers one. `lastBattle.died` alone could be
    // stale from a previous life, so it must agree with `player.dead`, set by the same ack.
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

    // Battle simulation happens ONLY on this explicit click — never on mount, hydrate, or
    // reconnect. Never add an effect that calls fight().
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
                <div
                    className="alert alert-danger"
                    {...narrativeHtml(`💢 ${narrative?.ambushLine ?? FALLBACK_AMBUSH_LINE}`)}
                />
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
            {/* Joined into one string: each line is its own sentence, separated by a space, and
                giving them an element apiece would add wrappers that carry nothing. */}
            <p {...narrativeHtml([narrative.critLine, narrative.killLine, narrative.deflectionLine].filter(Boolean).join(' '))} />
            <p {...narrativeHtml(narrative.outcomeLine)} />
        </>
    );
}
