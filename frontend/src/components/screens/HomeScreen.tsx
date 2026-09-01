import type { MouseEvent } from 'react';
import { useGameStore, type ScreenId } from '@/store/gameStore';
import { useBattleFight } from '@/socket/useBattleFight';
import SelectActionForm from '@/components/common/SelectActionForm';

// Travelling around town is a pure client-side navigation, no server round trip.
const DESTINATIONS: { value: ScreenId; label: string }[] = [
    { value: 'inn', label: '🍺 Inn' },
    { value: 'armors', label: '🛡️ Armor Shop' },
    { value: 'weapons', label: '🗡️ Weapon Shop' },
    { value: 'battle', label: '💀 Battlefield' },
    { value: 'suicide', label: '🥀 Commit Suicide' },
];

export default function HomeScreen() {
    const navigate = useGameStore(state => state.navigate);
    const { fight } = useBattleFight();

    function goToHighscores(e: MouseEvent<HTMLAnchorElement>) {
        e.preventDefault();
        navigate('highscores');
    }

    // An explicit click into Battle IS a real user action, so it fights immediately via the same
    // shared hook BattleScreen's own Fight button uses — never on page load.
    function goToDestination(value: string) {
        navigate(value as ScreenId);
        if (value === 'battle')
            fight();
    }

    return (
        <>
            <p>
                Welcome to <a href="#highscores" onClick={goToHighscores}>City of Aden</a>.
                <br />
                Where do you want to go next, or what do you want to do?
            </p>

            {/* noPlaceholder pre-selects the first destination — there's no "nothing picked" state. */}
            <SelectActionForm
                options={DESTINATIONS}
                noPlaceholder
                defaultButtonLabel="Travel"
                activeButtonLabel={value => (value === 'suicide' ? '⚰️ Perish' : 'Travel')}
                defaultVariant="btn"
                activeVariant="btn"
                pending={false}
                onSubmit={goToDestination}
            />
        </>
    );
}
