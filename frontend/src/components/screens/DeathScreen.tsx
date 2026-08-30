import { useGameStore } from '@/store/gameStore';
import { useAction } from '@/socket/useAction';

/**
 * `player.deathReason` is fixed server-side at time of death, so this screen never re-randomizes
 * it. `coward || cheated` drives styling only; the highscore button uses the server-computed
 * `highscoreEligible` rather than re-deriving the rule.
 */
export default function DeathScreen() {
    const player = useGameStore(state => state.player);
    const catalog = useGameStore(state => state.catalog);
    const hydrate = useGameStore(state => state.hydrate);
    const navigate = useGameStore(state => state.navigate);
    const submitAction = useAction('highscores:submit');
    const restartAction = useAction('game:restart');

    // `!player.dead` is defence in depth behind pinScreen, which already keeps the living off this
    // screen: it must be impossible to render "Play Again?" for a character that is still alive.
    if (!player || !player.dead)
        return null;

    function handleSubmit() {
        void submitAction.run({}, {
            onSuccess: data => {
                hydrate(data.hydrate);
                // Explicitly clears the filter when the slug can't be resolved, so a stale filter
                // from an earlier visit can never leak into this navigation.
                navigate('highscores', { raceFilter: catalog?.races.find(r => r.slug === data.raceSlug)?.id ?? null });
            },
        });
    }

    function handleRestart() {
        void restartAction.run({}, {
            onSuccess: data => {
                hydrate(data.hydrate);
                // Navigate explicitly rather than relying on hydrate()'s implicit reset
                // detection, which the server's own push for this mutation can race.
                navigate('start');
            },
        });
    }

    return (
        <>
            {player.coward || player.cheated
                ? <div className="alert alert-danger">{player.deathReason}</div>
                : <p>{player.deathReason}</p>}

            <div className="action-links">
                {player.highscoreEligible && (
                    <button type="button" className="btn" disabled={submitAction.pending} onClick={handleSubmit}>
                        📜 Write your Legacy!
                    </button>
                )}
                <button type="button" className="btn btn-secondary" disabled={restartAction.pending} onClick={handleRestart}>
                    Play Again?
                </button>
            </div>
        </>
    );
}
