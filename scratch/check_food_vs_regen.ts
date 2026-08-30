import 'dotenv/config';
import { RACES, FOODS, ARMORS } from '../backend/constant/game.constant';

function checkRestVsFood() {
    console.log(`\n--- Healing ROI (Rest vs Food) ---`);
    console.log(`${'Race'.padEnd(10)} | ${'Food Item'.padEnd(15)} | ${'Cost'.padEnd(6)} | ${'Wait (Ticks)'}`);
    console.log('-'.repeat(55));

    const targetHeal = 50; // We want to heal 50 HP

    RACES.forEach(race => {
        const baseRegen = race.regen;

        FOODS.slice(0, 3).forEach(food => {
            const ticksToRegen = baseRegen === 0 ? '∞' : Math.ceil(targetHeal / baseRegen).toString();

            console.log(
                `${race.label.padEnd(10)} | ` +
                `${food.name.padEnd(15)} | ` +
                `${food.cost.toString().padEnd(6)} | ` +
                `${ticksToRegen.padEnd(12)}`
            );
        });
        console.log('-'.repeat(55));
    });
}

checkRestVsFood();

process.exit(0);
