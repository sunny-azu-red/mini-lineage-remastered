import 'dotenv/config';
import { RACES, WEAPONS, ARMORS, MAX_LEVEL } from '../src/constant/game.constant';
import { simulateBattle } from '../src/service/battle.service';
import { calculateLevel } from '../src/service/math.service';

function checkEconomy(raceId: number) {
    const race = RACES[raceId];
    let experience = 0;
    let totalAdenaGenerated = 0;

    const totalGearCost =
        WEAPONS.reduce((sum, w) => sum + w.cost, 0) +
        ARMORS.reduce((sum, a) => sum + a.cost, 0);

    console.log(`\n--- Economy Balance Check: ${race.emoji} ${race.label} ---`);
    console.log(`Total cost of all Gear: 🪙 ${totalGearCost.toLocaleString()} Adena`);
    console.log('-'.repeat(50));

    while (calculateLevel(experience) < MAX_LEVEL) {
        const currentLevel = calculateLevel(experience);
        const weaponId = Math.min(5, Math.floor(currentLevel / 15));
        const armorId = Math.min(5, Math.floor(currentLevel / 15));

        const res = simulateBattle({
            raceId,
            weaponId,
            armorId,
            experience,
            health: race.startHealth,
            adena: 0,
            name: 'Hero'
        } as any);
        experience += res.xpGained;
        totalAdenaGenerated += res.adenaGained;
    }

    const surplus = totalAdenaGenerated - totalGearCost;
    const canAffordEverything = surplus >= 0;

    console.log(`Total Adena Earned at Lvl 80: 🪙 ${Math.round(totalAdenaGenerated).toLocaleString()}`);
    console.log(`Financial Status: ${canAffordEverything ? '✅ AFFORDABLE' : '❌ NOT AFFORDABLE'}`);
    if (!canAffordEverything) {
        console.log(`Shortfall: 🪙 ${Math.abs(Math.round(surplus)).toLocaleString()} Adena`);
    } else {
        console.log(`Surplus (for Food/Potions): 🪙 ${Math.round(surplus).toLocaleString()} Adena`);
    }
}

checkEconomy(0); // Human
checkEconomy(1); // Orc
checkEconomy(2); // Elf
checkEconomy(3); // Dark Elf
