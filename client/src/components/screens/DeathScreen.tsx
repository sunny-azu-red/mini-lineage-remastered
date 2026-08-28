import { useGameStore } from '@/store/gameStore';
import { useAction } from '@/socket/useAction';

/**
 * Ported from death.ejs. `player.deathReason` is fixed once, server-side, at time of death
 * (`resolveDeathReason` — see narrative.service.ts's neighbor in player.service.ts) so this
 * screen never re-randomizes it on repeated renders/reconnects the way the old EJS view did.
 *
 * `isCowardOrCheated` mirrors the deleted `player.view.ts`'s `renderDeathView` local of the same
 * name EXACTLY (`player.coward || player.cheated`) — despite the old EJS template's local
 * variable literally being named `coward`, it always meant "coward OR cheated" by the time it
 * reached the template. Used only for styling (danger alert vs. plain paragraph); the highscore
 * button's visibility uses `player.highscoreEligible` instead of recomputing the same condition,
 * per plan instruction — it's already server-computed as `dead && !coward && !cheated`.
 */
export default function DeathScreen() {
    const player = useGameStore(state => state.player);
    const catalog = useGameStore(state => state.catalog);
    const hydrate = useGameStore(state => state.hydrate);
    const navigate = useGameStore(state => state.navigate);
    const submitAction = useAction('highscores:submit');
    const restartAction = useAction('game:restart');

    if (!player)
        return null;

    const isCowardOrCheated = player.coward || player.cheated;

    function handleSubmit() {
        void submitAction.run(
            {},
            {
                onSuccess: data => {
                    hydrate(data.hydrate);
                    // RECONCILED: HighscoresScreen now exists with a real `raceFilter` (a raceId,
                    // not a slug — see gameStore's `highscoreRaceFilter`), so `data.raceSlug` is
                    // resolved to that id via `catalog.races` and passed straight into the
                    // navigate deep-link. Explicitly clears the filter (`null`, not "leave
                    // unchanged") if the slug can't be resolved for any reason, so a stale filter
                    // from an earlier highscores visit can never leak into this navigation;
                    // defensive only, shouldn't happen since the server derives the slug from the
                    // very same RACES table.
                    const resolvedRaceId = catalog?.races.find(r => r.slug === data.raceSlug)?.id ?? null;
                    navigate('highscores', { raceFilter: resolvedRaceId });
                },
            },
        );
    }

    function handleRestart() {
        void restartAction.run(
            {},
            {
                onSuccess: data => {
                    // `game:restart` resets the player in place (plan A9) and returns a fresh
                    // hydrate; `hydrate()` picks the right screen itself (routes to 'start' for
                    // the now-unstarted player — see gameStore.ts's `hydrate()`), no manual
                    // navigate() call needed here.
                    hydrate(data.hydrate);
                },
            },
        );
    }

    return (
        <>
            {isCowardOrCheated ? (
                <div className="alert alert-danger">{player.deathReason}</div>
            ) : (
                <p>{player.deathReason}</p>
            )}

            <div className="action-links">
                {player.highscoreEligible && (
                    <button type="button" className="btn" disabled={submitAction.pending} onClick={handleSubmit}>
                        📜 Write your Legacy!
                    </button>
                )}
                <button
                    type="button"
                    className="btn btn-secondary"
                    disabled={restartAction.pending}
                    onClick={handleRestart}
                >
                    Play Again?
                </button>
            </div>
        </>
    );
}
