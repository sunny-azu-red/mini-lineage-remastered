/**
 * What the reader chose, kept as `<kind>:<id>` (`panel:inventory`) in one cookie the server reads
 * for its first draw (`MiniLineageWeb.Kept`), so a reload is served as the reader left it. A
 * browser refusing cookies keeps nothing, and every choice opens where the template says.
 */
const COOKIE = '_mini_lineage_kept';
// Chrome's ceiling on a cookie's life; `refreshKept` restarts it on every visit.
const MAX_AGE = 400 * 24 * 60 * 60;

function read() {
    try {
        const pair = document.cookie.split('; ').find((c) => c.startsWith(`${COOKIE}=`));
        return new URLSearchParams(pair ? pair.slice(COOKIE.length + 1) : '');
    } catch {
        return new URLSearchParams();
    }
}

// URLSearchParams writes nothing a cookie value may not hold, so it needs no second encoding.
function write(entries) {
    const value = entries.toString();
    const secure = location.protocol === 'https:' ? '; Secure' : '';
    try {
        document.cookie = `${COOKIE}=${value}; Path=/; SameSite=Lax; Max-Age=${value ? MAX_AGE : 0}${secure}`;
    } catch {
        // Simply not remembered.
    }
}

export function recall(kind, id) {
    return read().get(`${kind}:${id}`);
}

/** Null forgets it, so a choice undone leaves nothing behind to be read back. */
export function keep(kind, id, value) {
    const entries = read();
    if (value === null) entries.delete(`${kind}:${id}`);
    else entries.set(`${kind}:${id}`, value);
    write(entries);
}

/** The cookie as it stands, handed over on every connect: a reconnect's page may be older. */
export function keptCookie() {
    return read().toString();
}

/** Rewritten on every visit, so a reader who keeps coming back keeps their choices. */
export function refreshKept() {
    const entries = read();
    if (entries.size > 0) write(entries);
}
