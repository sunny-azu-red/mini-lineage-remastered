import { acquireSessionLock } from '@/util/lock.util';
import { getSessionData, setSessionData } from '@/util/session-store.util';
import type { PlayerState } from '@/interface';
import { isGameStarted, syncZoneAuras } from '@/service/player.service';
import { SocketError } from './error';

/** Returned by a `withSession` mutator to mean "nothing changed" — skips the write + revision bump. */
export const NO_CHANGE: unique symbol = Symbol('NO_CHANGE');

export interface SessionContext {
    sessionId: string;
    session: Record<string, any>; // raw store object (carries `cookie` etc.)
    player: PlayerState; // same object reference, narrowed
    /** Whether the pre-mutation `syncZoneAuras` flipped the aura. Always false for `readSession`. */
    zoneChanged: boolean;
}

const EXPIRED = () => new SocketError('SESSION_EXPIRED', 'Your session has expired. Please refresh.');

async function loadContext(sessionId: string): Promise<SessionContext> {
    const session = await getSessionData(sessionId);
    if (!session)
        throw EXPIRED();

    return { sessionId, session, player: session as unknown as PlayerState, zoneChanged: false };
}

/**
 * lock -> load -> mutate -> persist -> release.
 *
 * `syncZoneAuras` runs BOTH before `mutate` (so the mutator can see `ctx.zoneChanged`) and after
 * it — the post-mutation pass is what makes aura state instant rather than tied to the 5s tick,
 * since a mutator like `game:start`/`battle:fight` changes `ambushed`/`currentScreen`/`dead`
 * during its own run. Either flip forces a persist, so a zone-only change is never dropped even
 * when `mutate` reports NO_CHANGE.
 */
export async function withSession<T>(
    sessionId: string,
    mutate: (ctx: SessionContext) => T | Promise<T> | typeof NO_CHANGE,
): Promise<T> {
    const release = await acquireSessionLock(sessionId);

    try {
        const ctx = await loadContext(sessionId);
        if (isGameStarted(ctx.player))
            ctx.zoneChanged = syncZoneAuras(ctx.player);

        const result = await mutate(ctx);

        const postZoneChanged = isGameStarted(ctx.player) ? syncZoneAuras(ctx.player) : false;

        if (result === NO_CHANGE && !ctx.zoneChanged && !postZoneChanged)
            return undefined as T;

        ctx.player.revision = (ctx.player.revision ?? 0) + 1;
        await setSessionData(sessionId, ctx.session);

        return (result === NO_CHANGE ? undefined : result) as T;
    } finally {
        release();
    }
}

/** Same load as `withSession`, but no lock, no write and no zone sync — for read-only handlers. */
export async function readSession<T>(
    sessionId: string,
    read: (ctx: SessionContext) => T | Promise<T>,
): Promise<T> {
    return read(await loadContext(sessionId));
}
