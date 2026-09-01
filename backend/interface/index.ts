import 'express-session';
import type { BattleOutcome, BattleNarrativeSnapshot, ScreenId } from '@shared/contract';
import { ALL_STAT_FIELDS } from '@/constant/statistics.constant';

// ---------------
// game & entities
// ---------------

export enum RaceType {
    Human = 0,
    Orc = 1,
    Elf = 2,
    DarkElf = 3,
}

export enum ItemType {
    Weapon = 'weapon',
    Armor = 'armor',
    Food = 'food',
}

export interface Race {
    id: RaceType;
    label: string;
    plural: string;
    emoji: string;
    enemyRaceId: RaceType;
    startHealth: number;
    startAdena: number;
    ambushChance: number;
    regen: number;
    crit: number;
    backstory: string;
}

export interface Item {
    id: number;
    name: string;
    emoji: string;
    stat: number;
    cost: number;
    modifiers?: readonly StatModifier[] | StatModifier[];
    effect?: EffectConfig;
}

export interface PurchaseResult {
    success: boolean;
    text: string;
    item?: Item;
}

// Aliased to the wire-level type so the two can never drift.
export type BattleResult = BattleOutcome;

// ----------------
// player & effects
// ----------------

export interface PlayerStats {
    attack: number;
    defense: number;
    crit: number;
    maxHealth: number;
    regen: number;
    ambushRisk: number;
    xpMultiplier: number;
    adenaMultiplier: number;
}

export type StatModifierType = keyof PlayerStats;

export interface StatModifierConfig {
    label: string;
    isMultiplier?: boolean;
    isPercentage?: boolean;
}

export interface StatModifier {
    type: StatModifierType;
    value: number;
}

export interface BaseEffect {
    id: string;
    type: 'buff' | 'debuff' | 'aura';
    group?: string;
    emoji: string;
    label: string;
    modifiers: readonly StatModifier[] | StatModifier[];
}

export interface EffectConfig extends BaseEffect {
    durationMs?: number;
}

export interface ActiveEffect extends BaseEffect {
    expiresAt?: number;
}

export interface PlayerState {
    name: string;
    raceId: RaceType;
    health: number;
    adena: number;
    experience: number;
    weaponId: number;
    armorId: number;
    dead?: boolean;
    ambushed?: boolean;
    coward?: boolean;
    cheated?: boolean;
    deathReason?: string;
    totalBattles?: number;
    totalAmbushes?: number;
    consecutiveAmbushes?: number;
    totalEnemiesKilled?: number;
    effects?: ActiveEffect[];
    revision?: number;
    /** Stamped by `player:screen`; syncZoneAuras classifies combat/resting zones purely from this. */
    currentScreen?: ScreenId;
    /** When the ⚔️ In Combat aura stops lingering after leaving a combat zone. See syncZoneAuras. */
    combatUntil?: number;
    bootstrappedAt?: number;
    /** The most recently resolved fight, persisted so it survives a reconnect. */
    lastBattleNarrative?: BattleNarrativeSnapshot;
}

export interface FlashMessage {
    text: string;
    type: 'success' | 'danger' | 'info' | 'warning';
    sound?: string;
}

// -----------------------
// persistence & transport
// -----------------------

export interface HighscoreEntry {
    name: string;
    race_id: RaceType;
    total_xp: number;
    adena: number;
    level: number;
    created: string;
}

export type StatField = (typeof ALL_STAT_FIELDS)[number];

export interface StatRow {
    name: StatField;
    value: number;
}

export type Statistics = {
    [K in StatField]: number;
};

export interface SessionTrackerEntry {
    socketIds: Set<string>;
    lastSeen: number;
    /** ONE timer, armed at the earliest upcoming effect deadline — always cleared and re-armed whole. */
    expiryTimer?: NodeJS.Timeout;
    inputBuffer?: string[];
}

declare module 'express-session' {
    interface SessionData extends PlayerState { }
}
