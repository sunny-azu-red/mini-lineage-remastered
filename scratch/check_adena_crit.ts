import 'dotenv/config';
import { simulateBattle } from '../backend/service/battle.service';

function runSimulation(raceId: number, weaponId: number, armorId: number, iterations: number = 1000) {
    let normalTotalAdena = 0;
    let normalCount = 0;
    let critTotalAdena = 0;
    let critCount = 0;

    // Use a simpler approach to bypass the read-only export if necessary
    // or just use the mathService as is but it's hard to mock without vi
    // Let's just run it 2000 times and filter the results by results.isCritical

    for (let i = 0; i < iterations * 10; i++) {
        const res = simulateBattle({
            raceId,
            weaponId,
            armorId,
            health: 100,
            experience: 0,
            adena: 0,
            name: 'Hero'
        } as any);

        if (res.isCritical) {
            critTotalAdena += res.adenaGained;
            critCount++;
        } else {
            normalTotalAdena += res.adenaGained;
            normalCount++;
        }
    }

    const normalAvg = normalTotalAdena / normalCount;
    const critAvg = critTotalAdena / critCount;
    const increase = ((critAvg - normalAvg) / normalAvg) * 100;

    console.log(`\n--- Results for Weapon ID: ${weaponId} ---`);
    console.log(`Sample Size: Normal(${normalCount}), Crit(${critCount})`);
    console.log(`Avg Adena (Normal):   ${Math.round(normalAvg).toLocaleString()}`);
    console.log(`Avg Adena (CRITICAL): ${Math.round(critAvg).toLocaleString()}`);
    console.log(`Actual Increase:      ${increase.toFixed(2)}%`);
}

console.log('SIMULATING BATTLES...');
runSimulation(0, 1, 1); // Starting weapon
runSimulation(0, 5, 5); // Late game weapon

process.exit(0);
