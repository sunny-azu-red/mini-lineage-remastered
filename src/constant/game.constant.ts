import { Item, Race, RaceType } from '@/interface';
import { getVersion } from '@/util/version.util';

export const GAME_VERSION = getVersion();
export const REPO_COMMIT_URL = 'https://github.com/sunny-azu-red/mini-lineage-remastered/commit/';

export const MAX_LEVEL = 80;
export const LOCALE = 'en-US';

/**
 * Race Data Configurations
 *
 * Starting values for each race
 */
export const RACES = [
    {
        id: RaceType.Human, label: `Human`, plural: `Humans`, emoji: `🧙`, enemyRaceId: RaceType.Orc,
        startHealth: 100, startAdena: 300, ambushChance: 8, regen: 1, crit: 4,
        backstory: `The most adaptable of all lineages. Humans possess a balanced constitution and steady precision, making them versatile survivors in a world that offers no quarter. They start with a modest inheritance and maintain a vigilant awareness of their surroundings.`
    },
    {
        id: RaceType.Orc, label: `Orc`, plural: `Orcs`, emoji: `🧟`, enemyRaceId: RaceType.Human,
        startHealth: 150, startAdena: 250, ambushChance: 16, regen: 0, crit: 0,
        backstory: `Towering warriors of immense physical resilience. Orcs possess the highest vitality at birth, but their massive presence makes them easy targets for ambushes. They lack natural regeneration and precision, relying instead on pure, unadulterated strength to crush their foes.`
    },
    {
        id: RaceType.Elf, label: `Elf`, plural: `Elves`, emoji: `🧝`, enemyRaceId: RaceType.DarkElf,
        startHealth: 75, startAdena: 450, ambushChance: 4, regen: 3, crit: 8,
        backstory: `Swift, wealthy, and favored by nature. Elves start their journey with significant gold and possess extraordinary natural healing and precision. They are incredibly difficult to surprise, though their physical frames are the most fragile of all the races.`
    },
    {
        id: RaceType.DarkElf, label: `Dark Elf`, plural: `Dark Elves`, emoji: `🧛`, enemyRaceId: RaceType.Elf,
        startHealth: 85, startAdena: 350, ambushChance: 5, regen: 2, crit: 11,
        backstory: `Lethal stalkers of the night. Dark Elves strike a deadly balance between physical power and supernatural resilience. They possess high precision and regeneration, with sturdier constitutions than their lighter cousins and a sharper edge in combat.`
    },
] satisfies Race[];

/**
 * Item Data Configurations
 *
 * Game combat math (HP lost, Enemies killed, XP and Adena gained) scales
 * dynamically based solely on the `stat` property of the equipped Weapon and Armor.
 *
 * You can seamlessly add new Items to the end of these arrays without breaking
 * the game engine, provided the `stat` roughly follows the established scaling curve.
 */
export const ARMORS = [
    { id: 0, name: `Peasant's Tunic`, emoji: '🧥', stat: 2, cost: 0 }, // start item
    { id: 1, name: `Brigandine Leathers`, emoji: '🥋', stat: 10, cost: 500 },
    { id: 2, name: `Spirit of the Forest`, emoji: '🪵', stat: 22, cost: 8_000 },
    { id: 3, name: `Knight's Plate`, emoji: '🛡️', stat: 41, cost: 30_000, regen: 1 },
    { id: 4, name: `Royal Chainmail`, emoji: '⛓️', stat: 64, cost: 140_000, regen: 2 },
    { id: 5, name: `Eternal Aegis`, emoji: '💎', stat: 88, cost: 400_000, regen: 3 },
] satisfies Item[];

export const WEAPONS = [
    { id: 0, name: `Brawler's Fists`, emoji: '👊', stat: 7, cost: 0 }, // start item
    { id: 1, name: `Elven Needle`, emoji: '🗡️', stat: 16, cost: 300 },
    { id: 2, name: `Stormbringer`, emoji: '⚡', stat: 28, cost: 5_000 },
    { id: 3, name: `Echos of Valhalla`, emoji: '⚔️', stat: 45, cost: 18_000, crit: 3 },
    { id: 4, name: `Calamity Comet`, emoji: '☄️', stat: 62, cost: 160_000, crit: 7 },
    { id: 5, name: `The Forgotten Blade`, emoji: '💀', stat: 90, cost: 600_000, crit: 15 },
] satisfies Item[];

export const FOODS = [
    { id: 0, name: 'Spiced Ale', emoji: '🍺', stat: 4, cost: 7 },
    { id: 1, name: 'Forest Apple', emoji: '🍎', stat: 6, cost: 11 },
    { id: 2, name: 'Smoked Sausage', emoji: '🌭', stat: 15, cost: 29 },
    { id: 3, name: 'Hearty Mash', emoji: '🥔', stat: 25, cost: 57 },
    { id: 4, name: 'Roasted Pheasant', emoji: '🍗', stat: 50, cost: 137 },
] satisfies Item[];

/**
 * HP Configuration
 */
export const HP_CONFIG = {
    lowHealthThreshold: 0.25,
} as const;

/**
 * Battle Scaling Configuration
 *
 * All tuning knobs for the combat simulation live here.
 * Adjust these values to rebalance the game without touching service logic.
 */
export const BATTLE_CONFIG = {
    enemyCount: { minMult: 0.3, maxMult: 0.6 },
    dangerLevel: { scaling: 0.6 },
    critChance: { multiplier: 1.5, floor: 1 },
    damageBlocked: { exponent: 0.95, scaling: 0.8 },
    xpGained: { exponent: 1.5, scaling: 0.8, killMin: 10, killMax: 18 },
    adenaGained: { exponent: 2.65, scaling: 0.05, killMin: 2, killMax: 4 },
    hpLost: { baseMin: 10, baseMax: 25, floor: 1 },
} as const;

/**
 * Tick Configuration
 *
 * Controls the server-side regen tick sent via WebSocket.
 * combatZones are paths where regen does NOT occur.
 * restingZones are paths where regen IS applied.
 */
export const TICK_CONFIG = {
    intervalMs: 5_000,
    combatZones: ['/battle', '/suicide', '/death'],
    restingZones: ['/', '/inn', '/shop/*', '/character', '/highscores', '/highscores/*'],
} as const;
