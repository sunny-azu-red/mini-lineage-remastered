import { acquireSessionLock } from '@/util/lock.util';
import { getSessionData, setSessionData } from '@/util/session-store.util';
import type { PlayerState } from '@/interface';
import { SocketError } from './error';

/**
 * Sentinel returned by a `withSession` mutator to signal "nothing changed" —
 * mirrors today's `if (!changed) { release(); return; }` early-out in
 * processSessionTick, avoiding an unnecessary write + revision bump.
 */
export const NO_CHANGE: unique symbol = Symbol('NO_CHANGE');

export interface SessionContext {
    sessionId: string;
    session: Record<string, any>; // raw store object (carries `cookie` etc.)
    player: PlayerState; // same object reference, narrowed
}

/**
 * The generalized lock -> load -> mutate -> persist helper. Replaces the
 * duplicated inline pattern in today's socket.service.ts (processSessionTick
 * and the Konami handler).
 */
export async function withSession<T>(
    sessionId: string,
    mutate: (ctx: SessionContext) => T | Promise<T> | typeof NO_CHANGE,
): Promise<T> {
    const release = await acquireSessionLock(sessionId);
    let released = false;
    const safeRelease = () => {
        if (released)
            return;

        released = true;
        release();
    };

    try {
        const session = await getSessionData(sessionId);
        if (!session)
            throw new SocketError('SESSION_EXPIRED', 'Your session has expired. Please refresh.');

        const ctx: SessionContext = { sessionId, session, player: session as unknown as PlayerState };
        const result = await mutate(ctx);

        if (result === NO_CHANGE)
            return undefined as T;

        ctx.player.revision = (ctx.player.revision ?? 0) + 1;
        await setSessionData(sessionId, ctx.session);

        return result as T;
    } finally {
        safeRelease();
    }
}

/**
 * Same load as `withSession`, but with no lock and no write — for read-only handlers.
 */
export async function readSession<T>(
    sessionId: string,
    read: (ctx: SessionContext) => T | Promise<T>,
): Promise<T> {
    const session = await getSessionData(sessionId);
    if (!session)
        throw new SocketError('SESSION_EXPIRED', 'Your session has expired. Please refresh.');

    const ctx: SessionContext = { sessionId, session, player: session as unknown as PlayerState };

    return read(ctx);
}
