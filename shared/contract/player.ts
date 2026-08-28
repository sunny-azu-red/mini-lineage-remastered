import type { BattleNarrativeSnapshot } from './battle-narrative';

export interface EffectView {
    id: string;
    type: 'buff' | 'debuff' | 'aura';
    emoji: string;
    label: string;
    /** Pre-formatted server-side via formatEffectTooltip() — "Label (+N Stat, ...)" */
    tooltip: string;
    /** Epoch ms. Client counts down locally for display; server remains authoritative on expiry. */
    expiresAt?: number;
}

export interface ItemView {
    id: number;
    name: string;
    emoji: string;
    stat: number;
    cost: number;
    // flattened, display-ready modifier values (today's Item.modifiers/effect.modifiers)
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
    /** Monotonic; bumped on every persisted mutation. Client drops stale out-of-order pushes. */
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
    /** dead && !coward && !cheated — server-computed so the client never re-derives eligibility rules. */
    highscoreEligible: boolean;

    counters: PlayerCounters;

    /**
     * The most recently resolved `battle:fight` narrative, persisted on `PlayerState` (as
     * `lastBattleNarrative`) so it survives any reconnect — never `null` for a player who has
     * fought at least once (even across reconnects), `null` for a never-started or
     * never-fought character. `ambushed`/`narrative.ambushLine` here are for DISPLAY TEXT only;
     * `PlayerSnapshot.ambushed` (above) remains the live, authoritative source for whether an
     * ambush is currently active.
     */
    lastBattle: BattleNarrativeSnapshot | null;
}
