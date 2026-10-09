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

/** Null forgets it, so a choice undone leaves nothing behind to be read back. */
export function keep(kind, id, value) {
    try {
        if (value === null) localStorage.removeItem(`${kind}:${id}`);
        else localStorage.setItem(`${kind}:${id}`, value);
    } catch {
        // Simply not remembered.
    }
}
