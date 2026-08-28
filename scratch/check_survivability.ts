import 'dotenv/config';
import { RACES } from '../backend/constant/game.constant';
import { simulateBattle } from '../backend/service/battle.service';

function checkSurvivability(raceId: number, weaponId: number, armorId: number, iterations: number = 1000) {
    const race = RACES[raceId];
    let deaths = 0;
    let totalHpLost = 0;

    for (let i = 0; i < iterations; i++) {
        const res = simulateBattle({
            raceId,
            weaponId,
            armorId,
            health: race.startHealth,
            experience: 0,
            adena: 0,
            name: 'Hero'
        } as any);
        totalHpLost += res.hpLost;
        
        // If a single battle takes more HP than the race's starting HP, we count it as a "Lethal Risk"
        if (res.hpLost >= race.startHealth) {
            deaths++;
        }
    }

    const avgHpLost = totalHpLost / iterations;
    const deathRate = (deaths / iterations) * 100;

    console.log(`\n--- Survivability: ${race.emoji} ${race.label} ---`);
    console.log(`Gear: Weapon(${weaponId}), Armor(${armorId})`);
    console.log(`Avg HP Lost per Battle: ${avgHpLost.toFixed(1)}`);
    console.log(`Lethal Risk (Death %):  ${deathRate.toFixed(2)}%`);
    
    if (deathRate > 5) {
        console.log(`⚠️ WARNING: High mortality rate for this gear level!`);
    } else {
        console.log(`✅ STABLE: Players are safe at this stage.`);
    }
}

console.log(`\nSIMULATING COMBAT DEADLINESS...`);
checkSurvivability(0, 0, 0); // Starting Human
checkSurvivability(2, 0, 0); // Starting Elf (Fragile)
checkSurvivability(1, 0, 0); // Starting Orc (Tanky)
checkSurvivability(0, 3, 3); // Mid-game Human

process.exit(0);
