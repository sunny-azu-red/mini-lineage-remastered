import { RACES, WEAPONS, ARMORS, FOODS, EFFECTS_CONFIG } from '../backend/constant/game.constant';
import { simulateBattle } from '../backend/service/battle.service';
import { getPlayerStats } from '../backend/service/player.service';
import { PlayerState } from '../backend/interface';

interface SimulationScenario {
    raceId: number;
    weaponTier: number;
    armorTier: number;
    foodTier: number | null; // null = baseline, 2 = sausage, 3 = mash, 4 = pheasant
    battlesPerMinute: number;
}

function runScenario(scenario: SimulationScenario, iterations: number = 10_000) {
    const race = RACES[scenario.raceId];
    const food = scenario.foodTier !== null ? FOODS[scenario.foodTier] : null;

    let totalAdenaEarned = 0;
    let totalXpEarned = 0;
    let totalHpLost = 0;
    let deaths = 0;

    for (let i = 0; i < iterations; i++) {
        const player: PlayerState = {
            raceId: race.id,
            name: 'SimPlayer',
            health: race.startHealth,
            adena: 100_000,
            experience: 0,
            weaponId: scenario.weaponTier,
            armorId: scenario.armorTier,
            totalBattles: 0,
            totalAmbushes: 0,
            consecutiveAmbushes: 0,
            totalEnemiesKilled: 0,
            effects: food?.effect ? [{
                id: food.effect.id,
                type: food.effect.type,
                group: food.effect.group,
                emoji: food.effect.emoji,
                label: food.effect.label,
                modifiers: food.effect.modifiers,
                expiresAt: Date.now() + 100_000,
            }] : [],
        };

        const stats = getPlayerStats(player);
        player.health = stats.maxHealth;

        const result = simulateBattle(player);
        totalAdenaEarned += result.adenaGained;
        totalXpEarned += result.xpGained;
        totalHpLost += result.hpLost;

        if (result.hpLost >= stats.maxHealth) {
            deaths++;
        }
    }

    const avgAdenaPerBattle = Math.round(totalAdenaEarned / iterations);
    const avgXpPerBattle = Math.round(totalXpEarned / iterations);
    const avgHpLostPerBattle = Math.round(totalHpLost / iterations);
    const deathRate = (deaths / iterations) * 100;

    return {
        avgAdenaPerBattle,
        avgXpPerBattle,
        avgHpLostPerBattle,
        deathRate,
    };
}

console.log('========================================================================');
console.log('MINI-LINEAGE FOOD BUFF DURATION & BALANCE SIMULATION');
console.log('========================================================================\n');

// Active foods with their configured durationMs in seconds
const activeFoods = [
    {
        name: 'Smoked Sausage',
        cost: FOODS[2].cost,
        durSec: (EFFECTS_CONFIG.smokedSausage.durationMs ?? 90_000) / 1000,
        maxHp: 10,
        foodIndex: 2,
    },
    {
        name: 'Hearty Mash',
        cost: FOODS[3].cost,
        durSec: (EFFECTS_CONFIG.heartyMash.durationMs ?? 150_000) / 1000,
        maxHp: 30,
        foodIndex: 3,
    },
    {
        name: 'Roasted Pheasant',
        cost: FOODS[4].cost,
        durSec: (EFFECTS_CONFIG.roastedPheasant.durationMs ?? 300_000) / 1000,
        maxHp: 60,
        foodIndex: 4,
    },
];

const gearTiers = [
    { name: 'Tier 0: Starter (Fists / Peasant)', weapon: 0, armor: 0, bpm: 20 },
    { name: 'Tier 1: Early Game (Elven Needle / Brigandine)', weapon: 1, armor: 1, bpm: 25 },
    { name: 'Tier 2: Mid Game (Stormbringer / Forest Spirit)', weapon: 2, armor: 2, bpm: 30 },
    { name: 'Tier 3: Advanced (Valhalla / Knight Plate)', weapon: 3, armor: 3, bpm: 35 },
    { name: 'Tier 4: High Tier (Calamity Comet / Royal Chain)', weapon: 4, armor: 4, bpm: 40 },
    { name: 'Tier 5: Endgame (Forgotten Blade / Eternal Aegis)', weapon: 5, armor: 5, bpm: 40 },
];

for (const gear of gearTiers) {
    console.log(`\n--- GEAR: ${gear.name} (Pacing: ~${gear.bpm} battles/min) ---`);
    const baseline = runScenario({ raceId: 0, weaponTier: gear.weapon, armorTier: gear.armor, foodTier: null, battlesPerMinute: gear.bpm });

    console.log(`Avg Income per Battle: ${baseline.avgAdenaPerBattle} Adena | Avg Damage Taken: ${baseline.avgHpLostPerBattle} HP`);

    for (const food of activeFoods) {
        const scenarioRes = runScenario({ raceId: 0, weaponTier: gear.weapon, armorTier: gear.armor, foodTier: food.foodIndex, battlesPerMinute: gear.bpm });

        const battlesDuringBuff = Math.round((food.durSec / 60) * gear.bpm);
        const grossAdena = battlesDuringBuff * scenarioRes.avgAdenaPerBattle;
        const netAdena = grossAdena - food.cost;
        const costPct = grossAdena > 0 ? ((food.cost / grossAdena) * 100).toFixed(1) : 'N/A';
        const displayDuration = food.durSec >= 60 ? `${(food.durSec / 60).toFixed(1)}m` : `${food.durSec}s`;

        console.log(`  > ${food.name} (+${food.maxHp} Max HP | Cost: ${food.cost} Adena | Duration: ${displayDuration} / ~${battlesDuringBuff} battles):`);
        console.log(`     Gross: ${grossAdena.toLocaleString()} Adena | Cost: ${costPct}% of income | Net Profit: +${netAdena.toLocaleString()} Adena`);
    }
}

process.exit(0);
