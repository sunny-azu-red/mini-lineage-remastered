import type { BattleNarrativeSnapshot } from './battle-narrative';

export interface EffectView {
    id: string;
    type: 'buff' | 'debuff' | 'aura';
    emoji: string;
    label: string;
    /** Pre-formatted server-side: "Label (+N Stat, ...)" */
    tooltip: string;
    /**
     * Ms left as of when the server built this snapshot — a DURATION, not a deadline, so the
     * client only ever counts down local elapsed time and two clocks never need reconciling.
     * Display only; the server remains authoritative on expiry and withdraws the effect itself.
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

    /** Last resolved fight, persisted so it survives reconnect; null only pre-first-fight. */
    lastBattle: BattleNarrativeSnapshot | null;
}
