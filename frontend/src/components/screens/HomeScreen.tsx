import type { MouseEvent } from 'react';
import { useGameStore, type ScreenId } from '@/store/gameStore';
import { useBattleFight } from '@/socket/useBattleFight';
import SelectActionForm from '@/components/common/SelectActionForm';

// Travelling around town never touched server state, so these are pure client-side navigations.
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

    // An explicit in-app click into Battle IS a real user action, so it fights immediately —
    // exactly like BattleScreen's own Fight button, and via the same shared hook. This is NOT the
    // old fight-on-page-load behaviour, which the anti-cheat redesign deliberately removed.
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

            {/*
             * `noPlaceholder` pre-selects the first destination, matching the old page's native
             * browser default — there is no reachable "nothing picked" value here. The button
             * label swaps for Suicide but its variant never does, unlike the shop/suicide forms.
             */}
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
