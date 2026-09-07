import { Fragment } from 'react';
import { useGameStore } from '@/store/gameStore';
import { narrativeHtml } from '@/components/common/narrative';
import BackLink from '@/components/common/BackLink';

// No server round-trip needed — `catalog.races` already carries each race's pre-filled traits HTML.
export default function RacesScreen() {
    const catalog = useGameStore(state => state.catalog);

    if (!catalog)
        return null;

    return (
        <>
            {catalog.races.map(race => (
                <Fragment key={race.id}>
                    <h2>{race.emoji} {race.label}</h2>
                    <p {...narrativeHtml(race.backstory)} />
                    <p {...narrativeHtml(race.traits)} />
                </Fragment>
            ))}

            <BackLink label="Go back to game start" />
        </>
    );
}
