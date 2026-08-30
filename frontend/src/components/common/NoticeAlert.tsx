import { useGameStore } from '@/store/gameStore';

// Wording is chosen client-side from the CURRENT `ambushed` state rather than trusted from the
// ack, since the server sends one generic RATE_LIMITED message. Purely flavor, not security.
const AMBUSH_RATE_LIMIT_MESSAGE = 'You are in the middle of an ambush and moving too fast, please wait a moment.';

const genericRateLimitMessage = (retryAfterSeconds: number | null): string =>
    retryAfterSeconds !== null
        ? `You are moving too fast, please take a breath and try again in ${retryAfterSeconds}s.`
        : 'You are moving too fast, please take a breath and try again in a moment.';

/**
 * The one shared renderer for `store.notice` (rate limits, INVALID_PAYLOAD, …). There is no
 * full-screen 429 page anymore, so a rejected action surfaces inline on the current screen.
 * RATE_LIMITED is special-cased here rather than in a second component — both render from the
 * same state, so a sibling would only duplicate this one's chrome or fight it over which renders.
 */
export default function NoticeAlert() {
    const notice = useGameStore(state => state.notice);
    const setNotice = useGameStore(state => state.setNotice);
    const player = useGameStore(state => state.player);

    if (!notice)
        return null;

    const isRateLimited = notice.code === 'RATE_LIMITED';
    const isAmbushRateLimited = Boolean(isRateLimited && player?.ambushed && !player?.dead);
    const retryAfterSeconds = notice.retryAfterMs ? Math.max(1, Math.ceil(notice.retryAfterMs / 1000)) : null;

    const message = !isRateLimited
        ? notice.message
        : isAmbushRateLimited ? AMBUSH_RATE_LIMIT_MESSAGE : genericRateLimitMessage(retryAfterSeconds);

    return (
        <div className="alert alert-danger alert-dismissible">
            {message}
            {isAmbushRateLimited && retryAfterSeconds !== null && <> Try again in {retryAfterSeconds}s.</>}
            <button type="button" className="alert-dismiss" aria-label="Dismiss" onClick={() => setNotice(null)}>×</button>
        </div>
    );
}
