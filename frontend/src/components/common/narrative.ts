/**
 * Server-composed narrative HTML (`<span class="xp">…`), spread onto the element that should
 * CONTAIN it rather than wrapped in an element of its own:
 *
 *     <p {...narrativeHtml(race.backstory)} />
 *
 * Safe by construction: no player-controlled string is ever interpolated into these templates
 * server-side. Do not widen its use without re-verifying that.
 */
export const narrativeHtml = (html: string) => ({ dangerouslySetInnerHTML: { __html: html } });
