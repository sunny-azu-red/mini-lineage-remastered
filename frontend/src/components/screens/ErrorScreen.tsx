import { useGameStore } from '@/store/gameStore';

interface ErrorScreenProps {
    detail?: string | null;
}

/**
 * Covers two failure modes with one visual: an unexpected render crash caught by ErrorBoundary
 * (`detail` = the thrown message, dev builds only), and the store's explicit `screen: 'error'`
 * navigation, which carries no message and so renders without `detail`.
 *
 * "Back" is `history.back()` when there is somewhere to go, else a plain navigate — the SPA
 * equivalent of the old hard `location.href = '/'`, with no reload. useHistorySync's popstate
 * handler turns a real back() into the right store transition, so this need not guess where it leads.
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
                <a href="#" onClick={e => { e.preventDefault(); handleBack(); }}>Return to safer lands</a>
            </p>
        </>
    );
}
