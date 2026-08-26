import 'dotenv/config';
import { RACES, WEAPONS, ARMORS } from '../src/constant/game.constant';
import { getEnemyCountRange, randomInt, calculateDangerLevel, calculateDamageBlocked, calculateBaseXpGained, calculateBaseAdenaGained } from '../src/service/math.service';
import { getPlayerStats } from '../src/service/player.service';
import { PlayerState } from '../src/interface';

// Custom simulation runner that accepts an explicit critMultiplier
function simCombat(player: PlayerState, critMultiplier: number, isCritical: boolean) {
    const stats = getPlayerStats(player);
    const attackPower = stats.attack;
    const defensePower = stats.defense;

    const { min: minEnemies, max: maxEnemies } = getEnemyCountRange(attackPower, 0.3, 0.6);
    let enemiesKilled = randomInt(minEnemies, maxEnemies);
    if (isCritical) {
        enemiesKilled = Math.max(1, Math.ceil(enemiesKilled * critMultiplier));
    }

    const dangerLevel = calculateDangerLevel(attackPower, 0.6);
    const damageBlocked = calculateDamageBlocked(defensePower, 0.95, 0.8);
    const hpLost = Math.max(1, randomInt(10, 25) + dangerLevel - damageBlocked);

    let xpGained = (enemiesKilled * randomInt(10, 18)) + calculateBaseXpGained(attackPower, 1.5, 0.8);
    let adenaGained = (enemiesKilled * randomInt(2, 4)) + calculateBaseAdenaGained(attackPower, 2.65, 0.05);

    if (isCritical) {
        xpGained = Math.ceil(xpGained * critMultiplier);
        adenaGained = Math.ceil(adenaGained * critMultiplier);
    }

    return { enemiesKilled, xpGained, adenaGained, hpLost, damageBlocked };
}

function runComparison(numTrials = 10000) {
    console.log(`\n========================================================================`);
    console.log(`      CRIT MULTIPLIER COMPARISON: 1.5x vs 1.9x (${numTrials.toLocaleString()} iterations)`);
    console.log(`========================================================================\n`);

    const tiers = [
        { label: `Early Game (${WEAPONS[0].name} / ${ARMORS[0].name})`, weaponId: 0, armorId: 0 },
        { label: `Mid Game (${WEAPONS[2].name} / ${ARMORS[3].name})`, weaponId: 2, armorId: 3 },
        { label: `End Game (${WEAPONS[4].name} / ${ARMORS[5].name})`, weaponId: 4, armorId: 5 },
    ];

    for (const tier of tiers) {
        console.log(`------------------------------------------------------------------------`);
        console.log(`  TIER: ${tier.label}`);
        console.log(`------------------------------------------------------------------------`);

        const p: PlayerState = {
            name: 'Hero',
            raceId: 0, // Human
            weaponId: tier.weaponId,
            armorId: tier.armorId,
            health: 100,
            experience: 0,
            adena: 0,
            effects: []
        };

        // Normal hits
        let normEnemies = 0, normXp = 0, normAdena = 0;
        // 1.5x hits
        let c15Enemies = 0, c15Xp = 0, c15Adena = 0;
        // 1.9x hits
        let c19Enemies = 0, c19Xp = 0, c19Adena = 0;

        for (let i = 0; i < numTrials; i++) {
            const n = simCombat(p, 1.5, false);
            normEnemies += n.enemiesKilled;
            normXp += n.xpGained;
            normAdena += n.adenaGained;

            const c15 = simCombat(p, 1.5, true);
            c15Enemies += c15.enemiesKilled;
            c15Xp += c15.xpGained;
            c15Adena += c15.adenaGained;

            const c19 = simCombat(p, 1.9, true);
            c19Enemies += c19.enemiesKilled;
            c19Xp += c19.xpGained;
            c19Adena += c19.adenaGained;
        }

        const avgNormEnemies = (normEnemies / numTrials).toFixed(1);
        const avg15Enemies = (c15Enemies / numTrials).toFixed(1);
        const avg19Enemies = (c19Enemies / numTrials).toFixed(1);

        const avgNormXp = Math.round(normXp / numTrials);
        const avg15Xp = Math.round(c15Xp / numTrials);
        const avg19Xp = Math.round(c19Xp / numTrials);

        const avgNormAdena = Math.round(normAdena / numTrials);
        const avg15Adena = Math.round(c15Adena / numTrials);
        const avg19Adena = Math.round(c19Adena / numTrials);

        console.log(`  [Enemies Defeated]`);
        console.log(`    Normal Hit : ${avgNormEnemies} enemies`);
        console.log(`    1.5x Crit  : ${avg15Enemies} enemies  (+${Math.round(((Number(avg15Enemies) - Number(avgNormEnemies)) / Number(avgNormEnemies)) * 100)}% vs normal)`);
        console.log(`    1.9x Crit  : ${avg19Enemies} enemies  (+${Math.round(((Number(avg19Enemies) - Number(avgNormEnemies)) / Number(avgNormEnemies)) * 100)}% vs normal) -> +${Math.round(((Number(avg19Enemies) - Number(avg15Enemies)) / Number(avg15Enemies)) * 100)}% boost over 1.5x\n`);

        console.log(`  [XP Gained]`);
        console.log(`    Normal Hit : ${avgNormXp.toLocaleString()} XP`);
        console.log(`    1.5x Crit  : ${avg15Xp.toLocaleString()} XP  (${((avg15Xp / avgNormXp)).toFixed(2)}x normal)`);
        console.log(`    1.9x Crit  : ${avg19Xp.toLocaleString()} XP  (${((avg19Xp / avgNormXp)).toFixed(2)}x normal) -> +${Math.round(((avg19Xp - avg15Xp) / avg15Xp) * 100)}% more XP than 1.5x\n`);

        console.log(`  [Adena Gained]`);
        console.log(`    Normal Hit : ${avgNormAdena.toLocaleString()} Adena`);
        console.log(`    1.5x Crit  : ${avg15Adena.toLocaleString()} Adena  (${((avg15Adena / avgNormAdena)).toFixed(2)}x normal)`);
        console.log(`    1.9x Crit  : ${avg19Adena.toLocaleString()} Adena  (${((avg19Adena / avgNormAdena)).toFixed(2)}x normal) -> +${Math.round(((avg19Adena - avg15Adena) / avg15Adena) * 100)}% more Adena than 1.5x\n`);
    }
}

runComparison(10000);


process.exit(0);
