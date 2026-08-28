export interface SessionTrackerEntry {
    socketIds: Set<string>;
    lastSeen: number;
    expiryTimers?: Map<string, NodeJS.Timeout>;
    inputBuffer?: string[];
}
