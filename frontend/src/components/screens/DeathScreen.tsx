import { useGameStore } from '@/store/gameStore';
import { useAction } from '@/socket/useAction';

// `deathReason` is fixed server-side at time of death, so this never re-randomizes it. The
// highscore button uses the server-computed `highscoreEligible` rather than re-deriving the rule.
export default function DeathScreen() {
    const player = useGameStore(state => state.player);
    const catalog = useGameStore(state => state.catalog);
    const hydrate = useGameStore(state => state.hydrate);
    const navigate = useGameStore(state => state.navigate);
    const submitAction = useAction('highscores:submit');
    const restartAction = useAction('game:restart');

    // Defence in depth behind pinScreen: must be impossible to render "Play Again?" for the living.
    if (!player || !player.dead)
        return null;

    function handleSubmit() {
        void submitAction.run({}, {
            onSuccess: data => {
                hydrate(data.hydrate);
                // Explicit null when the slug can't be resolved, so a stale filter never leaks in.
                navigate('highscores', { raceFilter: catalog?.races.find(r => r.slug === data.raceSlug)?.id ?? null });
            },
        });
    }

    function handleRestart() {
        void restartAction.run({}, {
            onSuccess: data => {
                hydrate(data.hydrate);
                // Explicit, rather than relying on hydrate()'s reset detection, which this mutation's
                // own server push can race.
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
