import 'express-session';
import type { BattleNarrativeSnapshot } from '@shared/contract';
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
    lastFightAt?: number;
    /**
     * Stamped by the `battle:leave` handler (fired by the client's navigate() when it transitions
     * away from the Battle screen) — see syncZoneAuras for how this, together with `lastFightAt`,
     * decides whether the combat aura's regen-blocking grace period has started yet.
     */
    battleLeftAt?: number;
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
