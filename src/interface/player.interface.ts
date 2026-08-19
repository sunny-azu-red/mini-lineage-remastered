import 'express-session';
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
    flash?: FlashMessage;
    totalBattles?: number;
    totalAmbushes?: number;
    consecutiveAmbushes?: number;
    totalEnemiesKilled?: number;
    effects?: ActiveEffect[];
}

export interface FlashMessage {
    text: string;
    type: 'success' | 'danger' | 'info' | 'warning';
}

export interface TickOptions {
    applyRegen?: boolean;
}

declare module 'express-session' {
    interface SessionData extends PlayerState { }
}
