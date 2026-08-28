/**
 * SessionLock — A per-session promise-based mutex to prevent concurrent
 * requests from causing "lost update" race conditions.
 *
 * Each session ID maps to a promise chain. New requests queue behind the
 * previous one, ensuring that only one handler at a time can read/write
 * session data for a given player.
 */

const locks = new Map<string, Promise<void>>();

/**
 * Acquires a lock for the given session ID.
 * Returns a release function that MUST be called when the work is done.
 */
export function acquireSessionLock(sessionId: string): Promise<() => void> {
    let release: () => void;

    const newLock = new Promise<void>((resolve) => {
        release = resolve;
    });

    const previous = locks.get(sessionId) ?? Promise.resolve();
    locks.set(sessionId, previous.then(() => newLock));

    return previous.then(() => release!);
}
