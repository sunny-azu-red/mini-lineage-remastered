import { acquireSessionLock } from '@/util/lock.util';
import { getSessionData, setSessionData } from '@/util/session-store.util';
import type { PlayerState } from '@/interface';
import { isGameStarted, syncZoneAuras } from '@/service/player.service';
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
    // Whether `withSession`'s automatic upfront `syncZoneAuras` call (below) actually
    // flipped the resting/combat aura for a started player. Always `false` for
    // `readSession` (which never syncs zones) and for a not-yet-started player.
    // A mutator that itself needs to know "did anything visible change" (e.g. the
    // periodic tick, whose own `processTick` check knows nothing about zones) should
    // fold this into its own decision — `withSession` also uses it independently as a
    // persistence safety net (see below) so a zone-only flip is never silently dropped.
    zoneChanged: boolean;
}

/**
 * The generalized lock -> load -> mutate -> persist helper. Replaces the
 * duplicated inline pattern in today's socket.service.ts (processSessionTick
 * and the Konami handler).
 *
 * `syncZoneAuras` runs automatically here, immediately after the session loads and
 * BEFORE `mutate` runs, for every started player — this is the "wired into every
 * withSession mutation" behavior the original zone-system design called for but never
 * actually implemented (previously only `battle:fight` and the tick called it). Its
 * returned boolean is folded into the persistence decision below: a zone-only change
 * (nothing else in the handler changed) must still persist and be observable to the
 * caller, which today it did not — a `mutate` reporting `NO_CHANGE` while the zone
 * silently flipped used to discard that flip entirely.
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

        const ctx: SessionContext = { sessionId, session, player: session as unknown as PlayerState, zoneChanged: false };
        if (isGameStarted(ctx.player))
            ctx.zoneChanged = syncZoneAuras(ctx.player);

        const result = await mutate(ctx);

        if (result === NO_CHANGE && !ctx.zoneChanged)
            return undefined as T;

        ctx.player.revision = (ctx.player.revision ?? 0) + 1;
        await setSessionData(sessionId, ctx.session);

        return (result === NO_CHANGE ? undefined : result) as T;
    } finally {
        safeRelease();
    }
}

/**
 * Same load as `withSession`, but with no lock and no write — for read-only handlers.
 * Never syncs zone auras (that would mutate the player), so `zoneChanged` is always `false`.
 */
export async function readSession<T>(
    sessionId: string,
    read: (ctx: SessionContext) => T | Promise<T>,
): Promise<T> {
    const session = await getSessionData(sessionId);
    if (!session)
        throw new SocketError('SESSION_EXPIRED', 'Your session has expired. Please refresh.');

    const ctx: SessionContext = { sessionId, session, player: session as unknown as PlayerState, zoneChanged: false };

    return read(ctx);
}
