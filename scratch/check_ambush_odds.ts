import 'dotenv/config';
import { RACES } from '../backend/constant/game.constant';
import { calculateAmbushChance } from '../backend/service/math.service';

function runAmbushSimulation(iterations: number = 1000000) {
    console.log(`\n--- Ambush Probability Simulation ---`);
    console.log(`Sample Size: ${iterations.toLocaleString()} rolls per race\n`);

    console.log(`${'Race'.padEnd(12)} | ${'Target %'.padEnd(10)} | ${'Actual %'.padEnd(10)} | ${'Deviation'.padEnd(10)}`);
    console.log('-'.repeat(50));

    RACES.forEach(race => {
        let ambushHits = 0;

        for (let i = 0; i < iterations; i++) {
            if (calculateAmbushChance(race.ambushChance)) {
                ambushHits++;
            }
        }

        const actualPercent = (ambushHits / iterations) * 100;
        const deviation = actualPercent - race.ambushChance;

        console.log(
            `${race.label.padEnd(12)} | ` +
            `${race.ambushChance.toFixed(2).padEnd(10)} | ` +
            `${actualPercent.toFixed(2).padEnd(10)} | ` +
            `${(deviation >= 0 ? '+' : '')}${deviation.toFixed(4)}%`
        );
    });

    console.log('\nSimulation complete.');
}

runAmbushSimulation();

process.exit(0);
