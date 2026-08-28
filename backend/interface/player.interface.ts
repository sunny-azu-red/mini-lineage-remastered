import 'express-session';
import type { BattleNarrativeSnapshot, ScreenId } from '@shared/contract';
import { RaceType } from './game.interface';

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
    /**
     * Stamped by the `player:screen` handler (fired by the client's navigate()/hydrate() on every
     * screen change) — see syncZoneAuras, which classifies combat/resting zones purely from this,
     * exactly like the old game's URL-path-based zone.middleware.ts did.
     */
    currentScreen?: ScreenId;
    bootstrappedAt?: number;
    /**
     * The narrative from the most recently resolved `battle:fight`, resolved once and persisted
     * here — mirrors `resolveDeathReason()`'s pattern for `deathReason` — so it rides along in
     * every `buildPlayerSnapshot()` call (as `PlayerSnapshot.lastBattle`) and survives any
     * reconnect, instead of existing only in that one fight's ack.
     */
    lastBattleNarrative?: BattleNarrativeSnapshot;
}

export interface FlashMessage {
    text: string;
    type: 'success' | 'danger' | 'info' | 'warning';
    sound?: string;
}

export interface TickOptions {
    applyRegen?: boolean;
}

declare module 'express-session' {
    interface SessionData extends PlayerState { }
}
