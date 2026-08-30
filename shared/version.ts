/**
 * Whether a version string names a release build — a release stamps the short git sha, anything
 * else (notably the '⚡ development' label) is a debug build.
 *
 * Shared so the server and the client cannot drift: the server ORs this with
 * `NODE_ENV === 'production'` (see backend/util/version.util.ts), while the client uses it alone
 * to decide whether to flag its own bundle as a debug build before the server has answered.
 */
export function isReleaseVersion(version: string): boolean {
    return version.length === 7 && /^[0-9a-f]+$/i.test(version);
}
