import { useGameStore } from '@/store/gameStore';

interface ErrorScreenProps {
    detail?: string | null;
}

/**
 * Ported from error.ejs. Covers two distinct failure modes with the same visual (see
 * ErrorBoundary.tsx's doc comment for the split): a truly unexpected render crash (caught by
 * ErrorBoundary, `detail` = the thrown error's message), and the store's explicit `screen:
 * 'error'` navigation for an expected-but-unrecoverable condition (no store field carries a
 * message for that case today, so `detail` is simply omitted there — a generic notice, exactly
 * like the old EJS page showed whenever `detail` was null, e.g. in a release build).
 *
 * `.js-back-link`'s old behavior (common.js) is ported literally: `history.back()` when there's
 * somewhere to go back to, else fall back to going home — the old app's fallback was a hard
 * `location.href = '/'`, which would force a full reload; the SPA equivalent is just `navigate()`
 * directly, no reload needed. `useHistorySync`'s `popstate` handler (see that hook) is what turns
 * a real `history.back()` into the correct store screen transition, so this component doesn't
 * need to know or guess where "back" leads in that case.
 */
export default function ErrorScreen({ detail = null }: ErrorScreenProps) {
    const player = useGameStore(state => state.player);
    const navigate = useGameStore(state => state.navigate);

    function handleBack() {
        if (window.history.length > 1)
            window.history.back();
        else
            navigate(player?.started ? 'home' : 'start');
    }

    return (
        <>
            <p>An unexpected error occurred on the server, please try again in a moment.</p>
            {detail && <pre className="code-block">{detail}</pre>}

            <p className="last">
                <a href="#" onClick={e => { e.preventDefault(); handleBack(); }}>
                    Return to safer lands
                </a>
            </p>
        </>
    );
}
