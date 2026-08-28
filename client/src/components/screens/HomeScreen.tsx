import type { MouseEvent } from 'react';
import { useGameStore, type ScreenId } from '@/store/gameStore';
import { useBattleFight } from '@/socket/useBattleFight';
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
    const { fight } = useBattleFight();

    function goToHighscores(e: MouseEvent<HTMLAnchorElement>) {
        e.preventDefault();
        navigate('highscores');
    }

    // Confirmed against the old app: `GET /battle` fought on EVERY load, including a plain
    // refresh — no distinction existed there. The rewrite's anti-cheat redesign correctly removed
    // auto-fighting on mount/reconnect (see BattleScreen.tsx's own doc comment — never add an
    // effect there), but an explicit in-app click into Battle from here IS a real user action, so
    // it should still fight immediately, exactly like clicking BattleScreen's own Fight button.
    // Firing `fight()` right after `navigate('battle')` (not awaited) is the same `battle:fight`
    // call BattleScreen/AmbushBanner already make via this same shared hook — not a new mechanism.
    //
    // `SelectActionForm` no longer gates submission on a real selection being made (Fix 1/7), so
    // submitting the placeholder here reaches this handler as `value === ''` — unlike Inn/Weapons
    // /Armors, Home has no "go home" meaning for that (you're already home), so it's just a no-op.
    function goToDestination(value: string) {
        if (!value)
            return;

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
                onSubmit={goToDestination}
            />
        </>
    );
}
