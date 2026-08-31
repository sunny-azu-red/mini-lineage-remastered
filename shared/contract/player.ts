import type { BattleNarrativeSnapshot } from './battle-narrative';

export interface EffectView {
    id: string;
    type: 'buff' | 'debuff' | 'aura';
    emoji: string;
    label: string;
    /** Pre-formatted server-side: "Label (+N Stat, ...)" */
    tooltip: string;
    /**
     * Milliseconds left when the server built this snapshot; absent for a permanent effect.
     *
     * A DURATION, not a deadline, on purpose. An absolute server epoch had to be compared against
     * the client's own clock, and `Math.ceil` turns any error in the "more time left" direction
     * into a whole extra second — a 5s aura reading 6. A duration is stamped against the client's
     * own receipt time, so the countdown can never start above the effect's real length, and
     * transport delay only ever errs the harmless way.
     *
     * Display only. The server remains authoritative on expiry and withdraws the effect itself.
     */
    remainingMs?: number;
}

export interface ItemView {
    id: number;
    name: string;
    emoji: string;
    stat: number;
    cost: number;
    // flattened, display-ready modifier values
    crit?: number;
    regen?: number;
    maxHealth?: number;
}

export interface StatsView {
    attack: number;
    defense: number;
    crit: number;
    regen: number;
    ambushRisk: number;
}

export interface PlayerCounters {
    totalBattles: number;
    totalAmbushes: number;
    consecutiveAmbushes: number;
    totalEnemiesKilled: number;
}

export interface PlayerSnapshot {
    /** Monotonic; bumped on every persisted mutation. The client drops stale out-of-order pushes. */
    revision: number;
    started: boolean;

    name: string | null;
    raceId: number | null;
    raceLabel: string | null;
    raceEmoji: string | null;

    health: number | null;
    maxHealth: number | null;
    hpPercent: number;
    lowHealth: boolean;

    experience: number | null;
    level: number | null;
    isMaxLevel: boolean;
    xpCurrent: number;
    xpRequired: number;
    xpPercent: number;
    xpNeeded: number;

    adena: number | null;

    weapon: ItemView | null;
    armor: ItemView | null;

    stats: StatsView | null;
    effects: EffectView[];

    dead: boolean;
    ambushed: boolean;
    coward: boolean;
    cheated: boolean;
    deathReason: string | null;
    /** dead && !coward && !cheated — computed here so the client never re-derives the rule. */
    highscoreEligible: boolean;

    counters: PlayerCounters;

    /**
     * The last resolved fight, persisted server-side so it survives a reconnect. Null only for a
     * character that has never fought. Its `ambushed`/`ambushLine` are DISPLAY TEXT only —
     * `PlayerSnapshot.ambushed` above stays the live source of truth.
     */
    lastBattle: BattleNarrativeSnapshot | null;
}
