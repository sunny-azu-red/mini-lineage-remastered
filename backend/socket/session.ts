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
    /** What the load-time sweep did, so a caller can log and persist it. See `loadContext`. */
    expiry: ExpiryReport;
}

/** The load-time expiry sweep's own account of itself. */
export interface ExpiryReport {
    /** Effects it removed — what the tick log names. */
    removed: ActiveEffect[];
    /** Health before it clamped, so a maxHealth buff lapsing still shows its HP drop. */
    healthBefore: number | undefined;
    /** Whether it changed anything, and therefore must persist. */
    changed: boolean;
}

const EXPIRED = () => new SocketError('SESSION_EXPIRED', 'Your session has expired. Please refresh.');

async function loadContext(sessionId: string): Promise<SessionContext> {
    const session = await getSessionData(sessionId);
    if (!session)
        throw EXPIRED();

    const player = session as unknown as PlayerState;
    const started = isGameStarted(player);

    /**
     * Zone auras FIRST, because `syncZoneAuras` owns them outright — it replaces the whole zone
     * aura every time, so an elapsed disengage countdown becomes Resting rather than being
     * "removed". Sweeping first would steal that and report a zone flip as an expiring effect.
     */
    const zoneChanged = started ? syncZoneAuras(player) : false;

    const healthBefore = player.health;
    const now = Date.now();
    const removed = (player.effects ?? []).filter(e => e.expiresAt !== undefined && e.expiresAt <= now);

    /**
     * Expiry happens HERE, before anything can read the player — the same reasoning that puts
     * `syncZoneAuras` on this path.
     *
     * An effect stops counting the instant its deadline passes, because `getActiveEffects` filters
     * by it. Sweeping on a separate schedule therefore split expiry into two moments: the stats
     * changed silently at the deadline, and the removal was announced (logged, pushed to the
     * client) whenever the sweep next ran. Doing it on load makes them the same moment, on every
     * path, without depending on any timer being punctual.
     */
    const changed = started ? processEffectExpiry(player) : false;

    return { sessionId, session, player, zoneChanged, expiry: { removed, healthBefore, changed } };
}

/**
 * lock -> load -> mutate -> persist -> release.
 *
 * `loadContext` sweeps expired effects first, so no mutator ever sees a player carrying one.
 *
 * `syncZoneAuras` runs in `loadContext` before `mutate` (so the mutator can see `ctx.zoneChanged`)
 * and again after
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
        const result = await mutate(ctx);

        const postZoneChanged = isGameStarted(ctx.player) ? syncZoneAuras(ctx.player) : false;

        // The sweep counts alongside the zone flips: a load whose only change was expiring an
        // effect still has to persist the tidied array and broadcast the new stats.
        if (result === NO_CHANGE && !ctx.zoneChanged && !postZoneChanged && !ctx.expiry.changed)
            return undefined as T;

        ctx.player.revision = (ctx.player.revision ?? 0) + 1;
        await setSessionData(sessionId, ctx.session);

        return (result === NO_CHANGE ? undefined : result) as T;
    } finally {
        release();
    }
}

/**
 * Same load as `withSession` — including the zone sync and expiry sweep, so a read sees exactly
 * the state a mutation would — but no lock and no write. For read-only handlers.
 */
export async function readSession<T>(
    sessionId: string,
    read: (ctx: SessionContext) => T | Promise<T>,
): Promise<T> {
    return read(await loadContext(sessionId));
}
