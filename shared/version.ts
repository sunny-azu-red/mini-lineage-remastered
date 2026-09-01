// A release stamps a short git sha; shared so server and client can't disagree on what that means.
export function isReleaseVersion(version: string): boolean {
    return version.length === 7 && /^[0-9a-f]+$/i.test(version);
}
