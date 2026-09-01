import { acquireSessionLock } from '@/util/lock.util';
import { getSessionData, setSessionData } from '@/util/session-store.util';
import type { ActiveEffect, PlayerState } from '@/interface';
import { isGameStarted, syncZoneAuras, processEffectExpiry } from '@/service/player.service';
import { SocketError } from './error';

/** Returned by a `withSession` mutator to mean "nothing changed" — skips the write + revision bump. */
export const NO_CHANGE: unique symbol = Symbol('NO_CHANGE');

export interface SessionContext {
    sessionId: string;
    session: Record<string, any>; // raw store object (carries `cookie` etc.)
    player: PlayerState; // same object reference, narrowed
    /** Whether the load-time `syncZoneAuras` flipped the aura. */
    zoneChanged: boolean;
    /** What the load-time expiry sweep did — see `loadContext`. */
    expiry: ExpiryReport;
}

export interface ExpiryReport {
    /** Effects it removed — what the tick log names. */
    removed: ActiveEffect[];
    /** Health before it clamped, so a maxHealth buff lapsing still shows its HP drop. */
    healthBefore: number | undefined;
    changed: boolean;
}

const EXPIRED = () => new SocketError('SESSION_EXPIRED', 'Your session has expired. Please refresh.');

async function loadContext(sessionId: string): Promise<SessionContext> {
    const session = await getSessionData(sessionId);
    if (!session)
        throw EXPIRED();

    const player = session as unknown as PlayerState;
    const started = isGameStarted(player);

    // Zone auras FIRST: syncZoneAuras replaces the whole aura, so an elapsed disengage countdown
    // becomes Resting rather than "removed". Sweeping first would misreport that as an expiry.
    const zoneChanged = started ? syncZoneAuras(player) : false;

    const healthBefore = player.health;
    const now = Date.now();
    const removed = (player.effects ?? []).filter(e => e.expiresAt !== undefined && e.expiresAt <= now);

    // Expiry happens HERE, on load, rather than on a separate schedule — so the stats changing
    // and the removal being announced (logged, pushed) are always the same moment.
    const changed = started ? processEffectExpiry(player) : false;

    return { sessionId, session, player, zoneChanged, expiry: { removed, healthBefore, changed } };
}

/**
 * lock -> load -> mutate -> persist -> release. Zone auras are synced again AFTER `mutate` too,
 * since a handler's own changes (ambushed/currentScreen/dead) can flip the zone — either sync
 * flipping forces a persist even when `mutate` itself reports NO_CHANGE.
 */
export async function withSession<T>(
    sessionId: string,
    mutate: (ctx: SessionContext) => T | Promise<T> | typeof NO_CHANGE,
): Promise<T> {
    const release = await acquireSessionLock(sessionId);

    try {
        const ctx = await loadContext(sessionId);
        const result = await mutate(ctx);

        const postZoneChanged = isGameStarted(ctx.player) ? syncZoneAuras(ctx.player) : false;

        if (result === NO_CHANGE && !ctx.zoneChanged && !postZoneChanged && !ctx.expiry.changed)
            return undefined as T;

        ctx.player.revision = (ctx.player.revision ?? 0) + 1;
        await setSessionData(sessionId, ctx.session);

        return (result === NO_CHANGE ? undefined : result) as T;
    } finally {
        release();
    }
}

/** Same load as `withSession` (zone sync + expiry sweep) but no lock and no write — read-only. */
export async function readSession<T>(
    sessionId: string,
    read: (ctx: SessionContext) => T | Promise<T>,
): Promise<T> {
    return read(await loadContext(sessionId));
}
