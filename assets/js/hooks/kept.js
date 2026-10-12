/**
 * What the reader chose, kept as `<kind>:<id>` (`panel:inventory`). Blocked
 * or private storage keeps nothing, so whatever it was opens where the template says.
 */
export function recall(kind, id) {
    try {
        return localStorage.getItem(`${kind}:${id}`);
    } catch {
        return null;
    }
}

/** Every kept `<kind>:<id>` of one kind, as `{id: value}`. */
export function recallAll(kind) {
    const all = {};
    try {
        for (let i = 0; i < localStorage.length; i++) {
            const key = localStorage.key(i);
            if (key?.startsWith(`${kind}:`)) all[key.slice(kind.length + 1)] = localStorage.getItem(key);
        }
    } catch {
        // As above: nothing kept, nothing to hand over.
    }
    return all;
}

/** Null forgets it, so a choice undone leaves nothing behind to be read back. */
export function keep(kind, id, value) {
    try {
        if (value === null) localStorage.removeItem(`${kind}:${id}`);
        else localStorage.setItem(`${kind}:${id}`, value);
    } catch {
        // Simply not remembered.
    }
}
