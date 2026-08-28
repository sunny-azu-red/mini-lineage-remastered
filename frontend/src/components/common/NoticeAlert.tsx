import { useGameStore } from '@/store/gameStore';

// Ported from rate-limit.ejs's two message variants (see the deleted battleRateLimitHandler /
// shopRateLimitHandler in the legacy rate-limit.middleware.ts) for wording — but chosen
// client-side off the CURRENT `player.ambushed` state rather than trusted from the server's ack,
// since the socket-side rate limiter (backend/socket/registry.ts) sends one generic
// "Too many requests. Please slow down." message for every RATE_LIMITED rejection regardless of
// cause. This is purely flavor text, not a security-relevant distinction.
const AMBUSH_RATE_LIMIT_MESSAGE =
    'You are in the middle of an ambush and moving too fast. Please wait a moment before your next move.';

// Folds the retry time directly into the sentence (rather than appending a second "Try again in
// Ns." after a message that already says "try again") so the retryAfterSeconds-known case reads
// as one clean sentence instead of two overlapping ones.
function genericRateLimitMessage(retryAfterSeconds: number | null): string {
    return retryAfterSeconds !== null
        ? `You are moving too fast. Please take a breath and try again in ${retryAfterSeconds}s.`
        : 'You are moving too fast. Please take a breath and try again in a moment.';
}

/**
 * The one, shared renderer for `store.notice` (socket error acks — rate limits, INVALID_PAYLOAD,
 * etc). Per the plan's "RateLimitNotice" section: there's no full-screen 429 page anymore (no
 * HTTP response to swap out), so a rejected action always surfaces here as an inline alert on
 * whatever screen the player is already on.
 *
 * DECISION: no separate `RateLimitNotice` component. `code === 'RATE_LIMITED'` is special-cased
 * right here instead — both render from the exact same `store.notice` state, so a second
 * component would either duplicate this one's dismiss/layout chrome or fight it over which one
 * renders when. Enhancing the one generic notice renderer keeps a single source of truth for
 * "what does a rejected action look like."
 */
export default function NoticeAlert() {
    const notice = useGameStore(state => state.notice);
    const setNotice = useGameStore(state => state.setNotice);
    const player = useGameStore(state => state.player);

    if (!notice)
        return null;

    const isRateLimited = notice.code === 'RATE_LIMITED';
    const isAmbushRateLimited = isRateLimited && player?.ambushed && !player?.dead;
    const retryAfterSeconds = notice.retryAfterMs ? Math.max(1, Math.ceil(notice.retryAfterMs / 1000)) : null;
    const message = isRateLimited
        ? isAmbushRateLimited
            ? AMBUSH_RATE_LIMIT_MESSAGE
            : genericRateLimitMessage(retryAfterSeconds)
        : notice.message;

    return (
        <div className="alert alert-danger alert-dismissible">
            {message}
            {isAmbushRateLimited && retryAfterSeconds !== null && <> Try again in {retryAfterSeconds}s.</>}
            <button
                type="button"
                className="alert-dismiss"
                aria-label="Dismiss"
                onClick={() => setNotice(null)}
            >
                ×
            </button>
        </div>
    );
}
