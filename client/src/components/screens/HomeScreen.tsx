import type { MouseEvent } from 'react';
import { useGameStore, type ScreenId } from '@/store/gameStore';
import SelectActionForm from '@/components/common/SelectActionForm';

// Static destination list ported verbatim from home.ejs's <select> options (same order, same
// emoji/copy). Today these are full page navigations (`<option value="/inn">`); here they're
// pure client-side `navigate()` calls — a real, intentional simplification vs. today's
// form-post-to-navigate pattern, since traveling around town never touched server state to begin
// with (it was only ever a `GET`). No `useAction`/server round-trip involved.
const DESTINATIONS: { value: ScreenId; label: string }[] = [
    { value: 'inn', label: '🍺 Inn' },
    { value: 'armors', label: '🛡️ Armor Shop' },
    { value: 'weapons', label: '🗡️ Weapon Shop' },
    { value: 'battle', label: '💀 Battlefield' },
    { value: 'suicide', label: '🥀 Commit Suicide' },
];

export default function HomeScreen() {
    const navigate = useGameStore(state => state.navigate);

    function goToHighscores(e: MouseEvent<HTMLAnchorElement>) {
        e.preventDefault();
        navigate('highscores');
    }

    return (
        <>
            <p>
                Welcome to <a href="#highscores" onClick={goToHighscores}>City of Aden</a>.
                <br />
                Where do you want to go next, or what do you want to do?
            </p>

            {/*
             * home.js's mechanism: the button's LABEL swaps to "⚰️ Perish" only when the suicide
             * destination is picked, but its CSS class never changes (always plain `.btn`) —
             * unlike shop.js/suicide.js, which swap both label and variant together. Hence
             * default/active variant are both left as plain 'btn' here.
             */}
            <SelectActionForm
                options={DESTINATIONS}
                placeholderLabel="Where to?"
                defaultButtonLabel="Travel"
                activeButtonLabel={value => (value === 'suicide' ? '⚰️ Perish' : 'Travel')}
                defaultVariant="btn"
                activeVariant="btn"
                pending={false}
                onSubmit={value => navigate(value as ScreenId)}
            />
        </>
    );
}
