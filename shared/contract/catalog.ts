import type { ItemView } from './player';

export interface RaceView {
    id: number;
    label: string;
    plural: string;
    emoji: string;
    slug: string;
    enemyRaceId: number;
    startHealth: number;
    startAdena: number;
    ambushChance: number;
    regen: number;
    crit: number;
    backstory: string;
    /** Pre-filled from RACE_TRAITS_TEMPLATES server-side; contains HTML spans (see narrative-safety invariant). */
    traits: string;
}

export interface GameCatalog {
    version: string;
    isRelease: boolean;
    year: number;
    locale: string;
    lowHealthThreshold: number;
    maxLevel: number;
    nameMinLength: number;
    nameMaxLength: number;
    races: RaceView[];
    weapons: ItemView[]; // index 0 = starting item, not purchasable
    armors: ItemView[];  // index 0 = starting item, not purchasable
    foods: ItemView[];
}
