import 'dotenv/config';
import { RACES, WEAPONS, ARMORS, FOODS, MAX_LEVEL } from '../src/constant/game.constant';
import { simulateBattle } from '../src/service/battle.service';
import { calculateLevel } from '../src/service/math.service';
import { PlayerState } from '../src/interface';

interface SimulationReport {
    race: string;
    totalBattles: number;
    totalAdenaEarned: number;
    totalSpentOnGear: number;
    totalSpentOnFood: number;
    totalMealsEaten: number;
    finalAdena: number;
    deaths: number;
    levelTimeline: Array<{ level: number; battles: number; adena: number; weaponId: number; armorId: number; }>;
}

function runFullLifecycleSimulation(raceId: number, strategy: 'cheap_food' | 'buff_food' = 'buff_food'): SimulationReport {
    const race = RACES[raceId];
    const player: PlayerState = {
        name: 'Player',
        raceId,
        weaponId: 0,
        armorId: 0,
        health: race.startHealth,
        experience: 0,
        adena: race.startAdena,
        cheated: false,
        dead: false,
        effects: []
    };

    let totalBattles = 0;
    let totalAdenaEarned = 0;
    let totalSpentOnGear = 0;
    let totalSpentOnFood = 0;
    let totalMealsEaten = 0;
    let deaths = 0;

    const levelTimeline: SimulationReport['levelTimeline'] = [];
    let lastRecordedLevel = 1;

    while (calculateLevel(player.experience) < MAX_LEVEL) {
        const currentLvl = calculateLevel(player.experience);

        // 1. Gear Upgrade Priority: check if next gear tier is available and affordable
        const nextWeapon = WEAPONS[player.weaponId + 1];
        if (nextWeapon && player.adena >= nextWeapon.cost) {
            player.adena -= nextWeapon.cost;
            totalSpentOnGear += nextWeapon.cost;
            player.weaponId++;
        }

        const nextArmor = ARMORS[player.armorId + 1];
        if (nextArmor && player.adena >= nextArmor.cost) {
            player.adena -= nextArmor.cost;
            totalSpentOnGear += nextArmor.cost;
            player.armorId++;
        }

        // 2. Simulate combat
        const res = simulateBattle(player);
        totalBattles++;
        player.experience += res.xpGained;
        player.adena += res.adenaGained;
        totalAdenaEarned += res.adenaGained;
        player.health = Math.max(0, player.health - res.hpLost);

        if (player.health === 0) {
            deaths++;
            player.health = race.startHealth; // Revive
        }

        // 3. Heal when below 40% HP:
        // Use food if player has a buffer of adena (> 300 adena or tier 1+ gear)
        const maxHp = race.startHealth;
        if (player.health < maxHp * 0.4) {
            // Select appropriate food tier for the gear level
            let food = FOODS[0]; // Spiced Ale (cost 7, heal 4)
            if (player.weaponId >= 4) {
                food = FOODS[4]; // Roasted Pheasant (cost 137, heal 50)
            } else if (player.weaponId >= 3) {
                food = FOODS[3]; // Hearty Mash (cost 57, heal 25)
            } else if (player.weaponId >= 1) {
                food = FOODS[2]; // Smoked Sausage (cost 29, heal 15)
            }

            while (player.health < maxHp * 0.8 && player.adena >= food.cost) {
                player.adena -= food.cost;
                totalSpentOnFood += food.cost;
                totalMealsEaten++;
                player.health = Math.min(maxHp + (food.effect?.modifiers[0]?.value ?? 0), player.health + food.stat);
            }
        }

        if (currentLvl !== lastRecordedLevel && (currentLvl % 10 === 0 || currentLvl === MAX_LEVEL)) {
            levelTimeline.push({
                level: currentLvl,
                battles: totalBattles,
                adena: player.adena,
                weaponId: player.weaponId,
                armorId: player.armorId
            });
            lastRecordedLevel = currentLvl;
        }
    }

    return {
        race: `${race.emoji} ${race.label}`,
        totalBattles,
        totalAdenaEarned,
        totalSpentOnGear,
        totalSpentOnFood,
        totalMealsEaten,
        finalAdena: player.adena,
        deaths,
        levelTimeline
    };
}

console.log(`\n======================================================`);
console.log(`    FULL LIFECYCLE SIMULATION: LEVEL 1 -> 80`);
console.log(`======================================================`);

[0, 1, 2, 3].forEach(raceId => {
    const report = runFullLifecycleSimulation(raceId, 'buff_food');
    console.log(`\n--- Race: ${report.race} ---`);
    console.log(`Total Battles:        ${report.totalBattles.toLocaleString()}`);
    console.log(`Total Adena Earned:   🪙 ${report.totalAdenaEarned.toLocaleString()}`);
    console.log(`Spent on Gear:        🪙 ${report.totalSpentOnGear.toLocaleString()}`);
    console.log(`Spent on Food:        🪙 ${report.totalSpentOnFood.toLocaleString()} (${report.totalMealsEaten.toLocaleString()} meals)`);
    console.log(`Final Surplus Adena:  🪙 ${report.finalAdena.toLocaleString()}`);
    console.log(`Combat Deaths:        ${report.deaths}`);
    console.log(`\nTimeline:`);
    console.log(`Level | Battles | Adena Bank | Weapon | Armor`);
    console.log(`-----------------------------------------------`);
    report.levelTimeline.forEach(t => {
        console.log(`${t.level.toString().padEnd(5)} | ${t.battles.toString().padEnd(7)} | 🪙 ${t.adena.toLocaleString().padEnd(10)} | ${WEAPONS[t.weaponId].name.padEnd(16)} | ${ARMORS[t.armorId].name}`);
    });
});

process.exit(0);
