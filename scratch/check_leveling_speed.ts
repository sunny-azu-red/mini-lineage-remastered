import 'dotenv/config';
import { RACES, MAX_LEVEL } from '../backend/constant/game.constant';
import { simulateBattle } from '../backend/service/battle.service';
import { calculateLevel } from '../backend/service/math.service';

function simulateLeveling(raceId: number) {
    const race = RACES[raceId];
    let totalBattles = 0;
    let experience = 0;
    let currentLevel = 1;

    console.log(`\n--- Leveling Speed Simulation: ${race.emoji} ${race.label} ---`);
    console.log(`${'Level'.padEnd(6)} | ${'Battles'.padEnd(10)} | ${'Total Battles'.padEnd(15)}`);
    console.log('-'.repeat(35));

    while (currentLevel < MAX_LEVEL) {
        let battlesAtLevel = 0;
        const targetLevel = currentLevel + 1;

        while (calculateLevel(experience) < targetLevel) {
            // Assume player always has the "best" weapon for their level to simulate optimal progress
            // (Weapon 0: 1-10, Weapon 1: 10-20, etc. roughly)
            const weaponId = Math.min(5, Math.floor(currentLevel / 15));
            const armorId = Math.min(5, Math.floor(currentLevel / 15));

            const res = simulateBattle({
                raceId,
                weaponId,
                armorId,
                health: race.startHealth,
                experience,
                adena: 0,
                name: 'Hero'
            } as any);
            experience += res.xpGained;
            battlesAtLevel++;
            totalBattles++;
        }

        currentLevel = calculateLevel(experience);
        if (currentLevel % 10 === 0 || currentLevel === MAX_LEVEL || currentLevel === 2) {
            console.log(`${currentLevel.toString().padEnd(6)} | ${battlesAtLevel.toString().padEnd(10)} | ${totalBattles.toString().padEnd(15)}`);
        }
    }

    console.log(`\nTotal battles to reach Level ${MAX_LEVEL}: ${totalBattles.toLocaleString()}`);
}

simulateLeveling(0); // Human
simulateLeveling(1); // Orc
simulateLeveling(2); // Elf
simulateLeveling(3); // Dark Elf

process.exit(0);
