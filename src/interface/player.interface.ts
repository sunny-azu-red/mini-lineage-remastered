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

export interface StatModifier {
    type: StatModifierType;
    value: number;
}

export interface ActiveEffect {
    id: string;
    type: 'buff' | 'debuff' | 'aura';
    icon: string;
    label: string;
    expiresAt?: number;
    modifiers: readonly StatModifier[] | StatModifier[];
}

export interface PlayerState {
    name: string;
    raceId: RaceType;
    health: number;
    prevHealth?: number;
    adena: number;
    prevAdena?: number;
    experience: number;
    prevExperience?: number;
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
