/**
 * The server-side half of an SNTP clock exchange (RFC 5905 §8) — timestamps T2 and T3, both read
 * from the SERVER's clock.
 *
 * Both are sent, rather than just one, so that time spent server-side between receiving the
 * request and answering it cancels out of the client's estimate instead of being mistaken for
 * network latency.
 */
export interface TimeSyncResponse {
    /** T2 — when the server received the request. */
    receivedAt: number;
    /** T3 — when the server sent this answer. */
    sentAt: number;
}
