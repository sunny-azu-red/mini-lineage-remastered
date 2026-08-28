import 'dotenv/config';
import { WEAPONS, ARMORS } from '../backend/constant/game.constant';

function checkEfficiency() {
    console.log(`\n--- Weapon Efficiency (Cost per Stat Point) ---`);
    console.log(`${'Weapon'.padEnd(20)} | ${'Stat'.padEnd(6)} | ${'Cost'.padEnd(10)} | ${'Cost/Stat'}`);
    console.log('-'.repeat(55));

    WEAPONS.forEach(w => {
        const costPerPoint = w.cost === 0 ? 0 : w.cost / w.stat;
        console.log(
            `${w.name.padEnd(20)} | ` +
            `${w.stat.toString().padEnd(6)} | ` +
            `${w.cost.toString().padEnd(10)} | ` +
            `${costPerPoint.toFixed(2)}`
        );
    });

    console.log(`\n--- Armor Efficiency (Cost per Stat Point) ---`);
    console.log(`${'Armor'.padEnd(20)} | ${'Stat'.padEnd(6)} | ${'Cost'.padEnd(10)} | ${'Cost/Stat'}`);
    console.log('-'.repeat(55));

    ARMORS.forEach(a => {
        const costPerPoint = a.cost === 0 ? 0 : a.cost / a.stat;
        console.log(
            `${a.name.padEnd(20)} | ` +
            `${a.stat.toString().padEnd(6)} | ` +
            `${a.cost.toString().padEnd(10)} | ` +
            `${costPerPoint.toFixed(2)}`
        );
    });
}

checkEfficiency();

process.exit(0);
