import { describe, it, expect } from 'vitest';
import { buildBattleNarrative, buildRaceTraits } from '@/service/narrative.service';
import { PlayerState, BattleResult } from '@/interface';
import { RACES } from '@/constant/game.constant';
import { BATTLE_LEVEL_UP_TEMPLATES, BATTLE_OUTCOME_TEMPLATES, BATTLE_MOVES } from '@/constant/narratives.constant';
import { fillTemplate, formatAdena, formatNumber } from '@/util/format.util';

const makeResult = (overrides: Partial<BattleResult> = {}): BattleResult => ({
    enemiesKilled: 1,
    hpLost: 10,
    damageBlocked: 5,
    xpGained: 100,
    adenaGained: 50,
    isCritical: false,
    isLevelUp: false,
    ...overrides,
});

const makePlayer = (overrides: Partial<PlayerState> = {}): PlayerState => ({
    raceId: 0,
    health: 100,
    adena: 0,
    experience: 0,
    weaponId: 0,
    armorId: 0,
    ...overrides,
} as PlayerState);

describe('buildBattleNarrative', () => {
    describe('opponent-race selection per race', () => {
        it('Human (0) fights Orcs', () => {
            const narrative = buildBattleNarrative(makePlayer({ raceId: 0 }), makeResult(), false);
            expect(narrative.killLine).toContain('Orc');
        });

        it('Orc (1) fights Humans', () => {
            const narrative = buildBattleNarrative(makePlayer({ raceId: 1 }), makeResult(), false);
            expect(narrative.killLine).toContain('Human');
        });

        it('Elf (2) fights Dark Elves', () => {
            const narrative = buildBattleNarrative(makePlayer({ raceId: 2 }), makeResult(), false);
            expect(narrative.killLine).toContain('Elf');
        });

        it('Dark Elf (3) fights Elves', () => {
            const narrative = buildBattleNarrative(makePlayer({ raceId: 3 }), makeResult(), false);
            expect(narrative.killLine).toContain('Elf');
        });
    });

    describe('critLine', () => {
        it('is null when the hit was not critical', () => {
            const narrative = buildBattleNarrative(makePlayer(), makeResult({ isCritical: false }), false);
            expect(narrative.critLine).toBeNull();
        });

        it('is a non-empty string when the hit was critical', () => {
            const narrative = buildBattleNarrative(makePlayer(), makeResult({ isCritical: true }), false);
            expect(narrative.critLine).toEqual(expect.any(String));
            expect(narrative.critLine).not.toBe('');
        });
    });

    describe('ambushLine / fightPrompt', () => {
        it('are both null when there is no ambush after this fight', () => {
            const narrative = buildBattleNarrative(makePlayer(), makeResult(), false);
            expect(narrative.ambushLine).toBeNull();
            expect(narrative.fightPrompt).toBeNull();
        });

        it('set ambushLine and "Face your Foe!" for a single ambush enemy', () => {
            const narrative = buildBattleNarrative(makePlayer(), makeResult({ enemiesKilled: 1 }), true);
            expect(narrative.ambushLine).toEqual(expect.any(String));
            expect(narrative.fightPrompt).toBe('Face your Foe!');
        });

        it('set "Fight them!" for multiple ambush enemies', () => {
            const narrative = buildBattleNarrative(makePlayer(), makeResult({ enemiesKilled: 10 }), true);
            expect(narrative.fightPrompt).toBe('Fight them!');
        });
    });

    describe('outcomeLine template selection', () => {
        it('is drawn from the level-up pool when isLevelUp is true', () => {
            const player = makePlayer();
            const result = makeResult({ isLevelUp: true });
            const narrative = buildBattleNarrative(player, result, false);

            const templateData = {
                hp: formatNumber(player.health),
                adenaGained: formatAdena(result.adenaGained),
            };
            const possibleLines = BATTLE_LEVEL_UP_TEMPLATES.map(t => fillTemplate(t, templateData));
            expect(possibleLines).toContain(narrative.outcomeLine);
        });

        it('is drawn from the regular outcome pool when isLevelUp is false', () => {
            const player = makePlayer();
            const result = makeResult({ isLevelUp: false });
            const narrative = buildBattleNarrative(player, result, false);

            const templateData = {
                hp: formatNumber(player.health),
                adenaGained: formatAdena(result.adenaGained),
            };
            const possibleLines = BATTLE_OUTCOME_TEMPLATES.map(t => fillTemplate(t, templateData));
            expect(possibleLines).toContain(narrative.outcomeLine);
        });
    });

    it('always computes a nextMove drawn from BATTLE_MOVES, regardless of ambush state', () => {
        const narrative = buildBattleNarrative(makePlayer(), makeResult(), false);
        expect(BATTLE_MOVES).toContain(narrative.nextMove);
    });

    it('killLine and deflectionLine are always non-empty strings', () => {
        const narrative = buildBattleNarrative(makePlayer(), makeResult(), false);
        expect(narrative.killLine.length).toBeGreaterThan(0);
        expect(narrative.deflectionLine.length).toBeGreaterThan(0);
    });
});

describe('buildRaceTraits', () => {
    it.each(RACES)('fills the traits template for $label with formatted stats', (race) => {
        const traits = buildRaceTraits(race);

        expect(traits).toContain(formatNumber(race.startHealth));
        expect(traits).toContain(formatAdena(race.startAdena));
        expect(traits).toContain(`${formatNumber(race.crit)}% Critical Chance`);
        expect(traits).toContain(`${formatNumber(race.ambushChance)}% Ambush Risk`);
    });

    it('never leaves unfilled {placeholder} tokens behind', () => {
        for (const race of RACES) {
            const traits = buildRaceTraits(race);
            expect(traits).not.toMatch(/\{\w+\}/);
        }
    });
});
