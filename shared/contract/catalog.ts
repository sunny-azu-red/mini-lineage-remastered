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
    /** Pre-filled server-side; contains HTML spans (see the narrative-safety invariant). */
    traits: string;
}

export interface GameCatalog {
    version: string;
    isRelease: boolean;
    /** The tagged commit, only for a release-shaped build; null for a dev build. */
    commitUrl: string | null;
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
