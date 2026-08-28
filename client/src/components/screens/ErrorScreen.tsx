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
 * `.js-back-link`'s old `history.back()` behavior is ported literally (not a fixed `navigate()`
 * destination) — `useHistorySync`'s `popstate` handler (see that hook) is what turns this browser
 * "back" into the correct store screen transition, so this component doesn't need to know or
 * guess where "back" leads.
 */
export default function ErrorScreen({ detail = null }: ErrorScreenProps) {
    function handleBack() {
        window.history.back();
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
