// Per-session promise-chain mutex: requests queue behind the previous one for the same session.
const locks = new Map<string, Promise<void>>();

/** Resolves once the previous holder (if any) releases; the returned fn MUST be called when done. */
export function acquireSessionLock(sessionId: string): Promise<() => void> {
    let release: () => void;
    const newLock = new Promise<void>((resolve) => { release = resolve; });
    const previous = locks.get(sessionId) ?? Promise.resolve();

    locks.set(sessionId, previous.then(() => newLock));

    return previous.then(() => release!);
}
