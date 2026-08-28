import type { HydratePayload } from './events';

export interface HighscoreRow {
    rank: number;
    name: string;
    raceId: number;
    level: number;
    totalXp: number;
    adena: number;
    created: string; // ISO 8601; client formats via shared/format.ts::formatShortDate
}

export interface HighscoreList {
    raceId: number | null;
    rows: HighscoreRow[];
}

export interface HighscoreSubmitResult {
    raceSlug: string | null;
    hydrate: HydratePayload; // fresh (reset) state — no reconnect round-trip needed
}
