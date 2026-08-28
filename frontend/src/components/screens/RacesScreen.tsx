import { Fragment, type MouseEvent } from 'react';
import { useGameStore } from '@/store/gameStore';
import Narrative from '@/components/common/Narrative';

/**
 * Ported from races.ejs. No server round-trip needed at all — `catalog.races` (already in the
 * store from `hydrate`) carries everything, including each race's pre-filled `traits` HTML (plan
 * decision A12 — rendered via `Narrative`, same safety invariant as CharacterScreen's use of it).
 */
export default function RacesScreen() {
    const catalog = useGameStore(state => state.catalog);
    const player = useGameStore(state => state.player);
    const navigate = useGameStore(state => state.navigate);

    if (!catalog)
        return null;

    function handleBack(e: MouseEvent<HTMLAnchorElement>) {
        e.preventDefault();
        navigate(player?.started ? 'home' : 'start');
    }

    return (
        <>
            {catalog.races.map(race => (
                <Fragment key={race.id}>
                    <h2>
                        {race.emoji} {race.label}
                    </h2>
                    <p>
                        <Narrative html={race.backstory} />
                    </p>
                    <p>
                        <Narrative html={race.traits} />
                    </p>
                </Fragment>
            ))}

            <p className="last back">
                <a href="#home" onClick={handleBack}>
                    Go back to game start
                </a>
            </p>
        </>
    );
}
