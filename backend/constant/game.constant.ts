import { Item, Race, RaceType, StatModifierType, StatModifierConfig, EffectConfig } from '@/interface';
import { getVersion } from '@/util/version.util';

export const GAME_VERSION = getVersion();
export const REPO_COMMIT_URL = 'https://github.com/sunny-azu-red/mini-lineage-remastered/commit/';

export const MAX_LEVEL = 80;
export const LOCALE = 'en-US';

/**
 * Stat Modifier Display Configurations
 *
 * Configures labels, units, and display rules for stat modifiers shown in buff/item tooltips.
 */
export const STAT_MODIFIER_CONFIG = {
    maxHealth: { label: 'Max HP' },
    regen: { label: 'HP Regen' },
    crit: { label: 'Crit', isPercentage: true },
    ambushRisk: { label: 'Ambush', isPercentage: true },
    attack: { label: 'Attack' },
    defense: { label: 'Defense' },
    xpMultiplier: { label: 'XP', isMultiplier: true },
    adenaMultiplier: { label: 'Adena', isMultiplier: true },
} as const satisfies Record<StatModifierType, StatModifierConfig>;

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
 * Effects Configuration
 *
 * All buffs, debuffs, town resting effects, and cheat parameters live here
 * for easy balance tuning in one single place.
 */
export const EFFECTS_CONFIG = {
    // auras
    restingAura: {
        id: 'resting',
        type: 'aura' as const,
        emoji: '💤',
        label: 'Resting',
        modifiers: [],
    },
    combatAura: {
        id: 'combat',
        type: 'aura' as const,
        emoji: '⚔️',
        label: 'In Combat',
        modifiers: [],
    },
    regenAura: {
        id: 'regenerating',
        type: 'aura' as const,
        emoji: '🌿',
        label: 'Regenerating',
        modifiers: [], // populated dynamically at runtime with total regen rate
    },

    // buffs / debuffs
    newbieBuff: {
        id: 'newbie_blessing',
        type: 'buff' as const,
        emoji: '🐣',
        label: 'Newbie Blessing',
        durationMs: 300_000, // 5m
        modifiers: [
            { type: 'maxHealth' as const, value: 20 },
            { type: 'defense' as const, value: 2 },
            { type: 'ambushRisk' as const, value: -4 },
        ],
    },
    ambushDebuff: {
        id: 'hexed',
        type: 'debuff' as const,
        emoji: '👁️',
        label: 'Hexed',
        durationMs: 60_000, // 1m
        modifiers: [
            { type: 'ambushRisk' as const, value: 4 },
            { type: 'crit' as const, value: -2 },
        ],
    },
    konamiCheat: {
        id: 'konami_cheat',
        type: 'debuff' as const,
        emoji: '👾',
        label: "Cheater's Mark",
        modifiers: [
            { type: 'xpMultiplier' as const, value: 4 },
            { type: 'adenaMultiplier' as const, value: 4 },
            { type: 'crit' as const, value: 15 },
            { type: 'maxHealth' as const, value: 150 },
        ],
    },

    // food buffs
    smokedSausage: {
        id: 'satisfied',
        type: 'buff' as const,
        group: 'food' as const,
        emoji: '🥓',
        label: 'Satisfied',
        durationMs: 90_000, // 1.5m
        modifiers: [{ type: 'maxHealth' as const, value: 10 }],
    },
    heartyMash: {
        id: 'well_fed',
        type: 'buff' as const,
        group: 'food' as const,
        emoji: '🍖',
        label: 'Well Fed',
        durationMs: 150_000, // 2.5m
        modifiers: [{ type: 'maxHealth' as const, value: 30 }],
    },
    roastedPheasant: {
        id: 'gourmet_feast',
        type: 'buff' as const,
        group: 'food' as const,
        emoji: '👑',
        label: 'Gourmet Feast',
        durationMs: 300_000, // 5m
        modifiers: [{ type: 'maxHealth' as const, value: 60 }],
    },
} as const satisfies Record<string, EffectConfig>;

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
    { id: 3, name: `Knight's Plate`, emoji: '🛡️', stat: 41, cost: 30_000, modifiers: [{ type: 'regen', value: 1 }] },
    { id: 4, name: `Royal Chainmail`, emoji: '⛓️', stat: 64, cost: 200_000, modifiers: [{ type: 'regen', value: 2 }] },
    { id: 5, name: `Eternal Aegis`, emoji: '💎', stat: 88, cost: 650_000, modifiers: [{ type: 'regen', value: 3 }] },
] satisfies Item[];

export const WEAPONS = [
    { id: 0, name: `Brawler's Fists`, emoji: '👊', stat: 7, cost: 0 }, // start item
    { id: 1, name: `Elven Needle`, emoji: '🗡️', stat: 16, cost: 300 },
    { id: 2, name: `Stormbringer`, emoji: '⚡', stat: 28, cost: 5_000 },
    { id: 3, name: `Echos of Valhalla`, emoji: '⚔️', stat: 45, cost: 18_000, modifiers: [{ type: 'crit', value: 3 }] },
    { id: 4, name: `Calamity Comet`, emoji: '☄️', stat: 62, cost: 250_000, modifiers: [{ type: 'crit', value: 7 }] },
    { id: 5, name: `The Forgotten Blade`, emoji: '💀', stat: 90, cost: 900_000, modifiers: [{ type: 'crit', value: 15 }] },
] satisfies Item[];

export const FOODS = [
    { id: 0, name: 'Spiced Ale', emoji: '🍺', stat: 4, cost: 7 },
    { id: 1, name: 'Forest Apple', emoji: '🍎', stat: 6, cost: 15 },
    { id: 2, name: 'Smoked Sausage', emoji: '🌭', stat: 15, cost: 60, effect: EFFECTS_CONFIG.smokedSausage },
    { id: 3, name: 'Hearty Mash', emoji: '🥔', stat: 35, cost: 250, effect: EFFECTS_CONFIG.heartyMash },
    { id: 4, name: 'Roasted Pheasant', emoji: '🍗', stat: 65, cost: 1_200, effect: EFFECTS_CONFIG.roastedPheasant },
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
    critReward: { multiplier: 1.9, floor: 1 },
    damageBlocked: { exponent: 0.95, scaling: 0.8 },
    xpGained: { exponent: 1.5, scaling: 0.8, killMin: 10, killMax: 18 },
    adenaGained: { exponent: 2.65, scaling: 0.05, killMin: 2, killMax: 4 },
    hpLost: { baseMin: 10, baseMax: 25, floor: 1 },
} as const;

/**
 * Tick & Zone Configuration
 *
 * Controls the server-side tick cadence and zone classifications.
 * combatZones are paths where passive ticks pause HP regeneration.
 * restingZones are paths where peaceful HP regeneration is applied.
 */
export const TICK_CONFIG = {
    intervalMs: 5_000,
    combatZones: ['/battle', '/suicide', '/death'],
    restingZones: ['/', '/inn', '/shop/*', '/character', '/highscores', '/highscores/*'],
    combatLingerMs: 10_000,
    // Safety net ONLY — see player.service.ts's syncZoneAuras. A player who fought and never
    // explicitly left the Battle screen (battle:leave) stays fully combat-blocked indefinitely,
    // same as an ambush; this caps that at a generous ceiling so a tab closed/abandoned mid-fight
    // doesn't block regen forever. Deliberately much longer than combatLingerMs so it never
    // interferes with the normal (explicit-leave) grace period.
    combatAbandonedMs: 5 * 60_000,
} as const;

/**
 * Session Configuration
 */
export const SESSION_CONFIG = {
    shortIdLength: 7,
    gracePeriodMs: 10_000,
} as const;

/**
 * Cheat / Secret Sequence Configuration
 */
export const CHEAT_CONFIG = {
    konamiSequence: ['arrowup', 'arrowup', 'arrowdown', 'arrowdown', 'arrowleft', 'arrowright', 'arrowleft', 'arrowright', 'b', 'a'],
} as const;

/**
 * Character Generation & Validation Configuration
 */
export const CHARACTER_CONFIG = {
    minAge: 9,
    maxAge: 69,
    ageThresholds: {
        youth: 23,
        adult: 54,
        labels: {
            youth: 'youth',
            adult: 'adult',
            elder: 'elder',
        },
    },
    nameMinLength: 1,
    nameMaxLength: 20,
    builds: ['a hardy', 'a wiry', 'a sturdy', 'a fit', 'a rugged', 'a robust', 'a solid'],
} as const;

/**
 * Highscores Configuration
 */
export const HIGHSCORES_CONFIG = {
    limit: 25,
} as const;

/**
 * Rate Limiting Configuration
 */
export const RATE_LIMIT_CONFIG = {
    battle: {
        windowMs: 60 * 1000, // 1 minute
        limit: 60, // 60 battles per minute
    },
    shop: {
        windowMs: 60 * 1000, // 1 minute
        limit: 30, // 30 shop actions per minute
    },
    flood: {
        windowMs: 60 * 1000, // 1 minute
        limit: 300, // 300 events per minute, applied to every socket event
    },
} as const;
