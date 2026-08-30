/**
 * A per-session promise-chain mutex. Each session id maps to a chain; new requests queue behind
 * the previous one so only one handler at a time can read/write a given player's session data.
 * The returned release function MUST be called when the work is done.
 */
const locks = new Map<string, Promise<void>>();

export function acquireSessionLock(sessionId: string): Promise<() => void> {
    let release: () => void;
    const newLock = new Promise<void>((resolve) => { release = resolve; });
    const previous = locks.get(sessionId) ?? Promise.resolve();

    locks.set(sessionId, previous.then(() => newLock));

    return previous.then(() => release!);
}
