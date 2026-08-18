import { describe, it, expect } from 'vitest';
import { formatAdena, formatNumber, pluralize, fillTemplate, slugify, formatShopItems, truncate, formatEffectModifier, formatEffectTooltip, formatSessionId, capitalize, formatEffectTimer } from '@/util/format.util';
import { EFFECTS_CONFIG } from '@/constant/game.constant';

describe('formatAdena', () => {
    it('returns plain number below 1k', () => expect(formatAdena(999)).toBe('999'));
    it('returns 1k for exactly 1000', () => expect(formatAdena(1_000)).toBe('1k'));
    it('returns 1.5k for 1500', () => expect(formatAdena(1_500)).toBe('1.5k'));
    it('strips trailing .0 from k', () => expect(formatAdena(5_000)).toBe('5k'));
    it('does NOT round up 4,950 to 5k (should be 4.9k)', () => expect(formatAdena(4_950)).toBe('4.9k'));
    it('does NOT round up 4,999 to 5k', () => expect(formatAdena(4_999)).toBe('4.9k'));
    it('returns kk for millions', () => expect(formatAdena(1_000_000)).toBe('1kk'));
    it('returns 1.2kk for 1,250,000 (floored)', () => expect(formatAdena(1_250_000)).toBe('1.2kk'));
    it('returns kkk for billions', () => expect(formatAdena(1_000_000_000)).toBe('1kkk'));
    it('handles negative numbers below 1k', () => expect(formatAdena(-500)).toBe('-500'));
    it('handles negative thousands', () => expect(formatAdena(-1_500)).toBe('-1.5k'));
    it('floors negative values correctly', () => expect(formatAdena(-4_950)).toBe('-4.9k'));
});

describe('formatNumber', () => {
    it('returns plain number below 1k', () => expect(formatNumber(999)).toBe('999'));
    it('formats thousands with commas', () => expect(formatNumber(1_000)).toBe('1,000'));
    it('formats millions with commas', () => expect(formatNumber(1_000_000)).toBe('1,000,000'));
    it('formats negative numbers with commas', () => expect(formatNumber(-2_500)).toBe('-2,500'));
});

describe('pluralize', () => {
    it('uses "a" for consonant-starting words', () => expect(pluralize('Human', 'Humans', 1)).toBe('a Human'));
    it('uses "an" for vowel-starting words (e, i, o, u)', () => {
        expect(pluralize('Elf', 'Elves', 1)).toBe('an Elf');
        expect(pluralize('Imp', 'Imps', 1)).toBe('an Imp');
        expect(pluralize('Orc', 'Orcs', 1)).toBe('an Orc');
        expect(pluralize('Undead', 'Undead', 1)).toBe('an Undead');
    });
    it('uses count + plural for multiple', () => expect(pluralize('Human', 'Humans', 3)).toBe('3 Humans'));
    it('includes emoji when provided', () => expect(pluralize('Human', 'Humans', 2, '🧙')).toBe('2 🧙 Humans'));
    it('includes emoji in singular', () => expect(pluralize('Elf', 'Elves', 1, '🧝')).toBe('an 🧝 Elf'));
});

describe('fillTemplate', () => {
    it('substitutes a simple variable', () => {
        expect(fillTemplate('Hello {name}!', { name: 'World' })).toBe('Hello World!');
    });
    it('leaves missing keys as-is', () => {
        expect(fillTemplate('{missing}', {})).toBe('{missing}');
    });
    it('handles ternary with single quotes', () => {
        expect(fillTemplate("{flag ? 'yes' : 'no'}", { flag: true })).toBe('yes');
        expect(fillTemplate("{flag ? 'yes' : 'no'}", { flag: false })).toBe('no');
    });
    it('handles ternary with double quotes', () => {
        expect(fillTemplate('{flag ? "yes" : "no"}', { flag: true })).toBe('yes');
        expect(fillTemplate('{flag ? "yes" : "no"}', { flag: false })).toBe('no');
    });
    it('returns empty string for empty template', () => {
        expect(fillTemplate('', {})).toBe('');
    });
});

describe('slugify', () => {
    it('lowercases and replaces spaces', () => expect(slugify('Hello World')).toBe('hello-world'));
    it('removes special characters', () => expect(slugify('Orcs & Humans!')).toBe('orcs-humans'));
    it('collapses multiple dashes', () => expect(slugify('test---test')).toBe('test-test'));
});

describe('formatShopItems', () => {
    it('formats a list of shop items correctly', () => {
        const items = [
            { id: 0, emoji: '🗡️', name: 'Dagger', stat: 10, cost: 100, modifiers: [{ type: 'crit', value: 5 }] },
            {
                id: 1,
                emoji: '🌭',
                name: 'Sausage',
                stat: 15,
                cost: 29,
                effect: { id: 'satisfied', type: 'buff', emoji: '🥓', label: 'Satisfied', modifiers: [{ type: 'maxHealth', value: 10 }] }
            },
            { id: 2, emoji: '🍎', name: 'Apple', stat: 6, cost: 11 }
        ] as any;
        const formatted = formatShopItems(items);
        expect(formatted[0]).toEqual({
            id: 0,
            emoji: '🗡️',
            name: 'Dagger',
            stat: 10,
            cost: 100,
            modifiers: [{ type: 'crit', value: 5 }],
            statFormatted: '10',
            costFormatted: '100'
        });
        expect(formatted[1]).toEqual({
            id: 1,
            emoji: '🌭',
            name: 'Sausage',
            stat: 15,
            cost: 29,
            effect: { id: 'satisfied', type: 'buff', emoji: '🥓', label: 'Satisfied', modifiers: [{ type: 'maxHealth', value: 10 }] },
            modifiers: [{ type: 'maxHealth', value: 10 }],
            statFormatted: '15',
            costFormatted: '29'
        });
        expect(formatted[2]).toEqual({
            id: 2,
            emoji: '🍎',
            name: 'Apple',
            stat: 6,
            cost: 11,
            modifiers: [],
            statFormatted: '6',
            costFormatted: '11'
        });
    });
});

describe('truncate', () => {
    it('returns the same string if it is shorter than the limit', () => {
        expect(truncate('Hello', 10)).toBe('Hello');
    });

    it('returns the same string if it is exactly the limit', () => {
        expect(truncate('Hello', 5)).toBe('Hello');
    });

    it('truncates and adds ellipsis if it is longer than the limit', () => {
        expect(truncate('Hello World', 5)).toBe('Hello...');
    });

    it('handles empty strings', () => {
        expect(truncate('', 5)).toBe('');
    });

    it('handles limit of 0', () => {
        expect(truncate('Hello', 0)).toBe('...');
    });
});

describe('formatEffectModifier', () => {
    it('formats positive maxHealth', () => expect(formatEffectModifier({ type: 'maxHealth', value: 10 })).toBe('+10 Max HP'));
    it('formats positive regen', () => expect(formatEffectModifier({ type: 'regen', value: 2 })).toBe('+2 HP Regen'));
    it('formats positive crit', () => expect(formatEffectModifier({ type: 'crit', value: 15 })).toBe('+15% Crit'));
    it('formats negative crit', () => expect(formatEffectModifier({ type: 'crit', value: -2 })).toBe('-2% Crit'));
    it('formats positive ambushRisk', () => expect(formatEffectModifier({ type: 'ambushRisk', value: 4 })).toBe('+4% Ambush'));
    it('formats positive attack', () => expect(formatEffectModifier({ type: 'attack', value: 5 })).toBe('+5 Attack'));
    it('formats positive defense', () => expect(formatEffectModifier({ type: 'defense', value: 3 })).toBe('+3 Defense'));
    it('formats multipliers', () => {
        expect(formatEffectModifier({ type: 'xpMultiplier', value: 6 })).toBe('6x XP');
        expect(formatEffectModifier({ type: 'adenaMultiplier', value: 6 })).toBe('6x Adena');
    });
    it('handles fallback unknown modifier types', () => {
        expect(formatEffectModifier({ type: 'speed' as any, value: 5 })).toBe('+5 speed');
    });
});

describe('formatEffectTooltip', () => {
    it('returns bare label when no modifiers exist', () => {
        expect(formatEffectTooltip(EFFECTS_CONFIG.restingAura)).toBe('Resting');
        expect(formatEffectTooltip({ label: 'Resting' })).toBe('Resting');
    });

    it('formats single modifier tooltip', () => {
        expect(formatEffectTooltip(EFFECTS_CONFIG.smokedSausage)).toBe('Satisfied (+10 Max HP)');
    });

    it('formats multiple modifier tooltip', () => {
        expect(formatEffectTooltip(EFFECTS_CONFIG.newbieBuff)).toBe('Newbie Blessing (+20 Max HP, +2 Defense, -4% Ambush)');
        expect(formatEffectTooltip(EFFECTS_CONFIG.ambushDebuff)).toBe('Hexed (+4% Ambush, -2% Crit)');
        expect(formatEffectTooltip(EFFECTS_CONFIG.konamiCheat)).toBe("Cheater's Mark (6x XP, 6x Adena, +15% Crit, +150 Max HP)");
    });
});

describe('formatSessionId', () => {
    it('slices session ID to 7 characters by default', () => {
        expect(formatSessionId('knTrfcRHsoP5sxrEdzK-ublzEUb6Z7F4')).toBe('knTrfcR');
    });

    it('slices session ID to custom length', () => {
        expect(formatSessionId('knTrfcRHsoP5sxrEdzK-ublzEUb6Z7F4', 10)).toBe('knTrfcRHso');
    });

    it('returns placeholder dashes if session ID is undefined or empty', () => {
        expect(formatSessionId(undefined)).toBe('-------');
        expect(formatSessionId('')).toBe('-------');
    });

    it('returns custom-length placeholder dashes if session ID is missing', () => {
        expect(formatSessionId(undefined, 5)).toBe('-----');
    });
});

describe('capitalize', () => {
    it('capitalizes the first letter of a word', () => {
        expect(capitalize('buff')).toBe('Buff');
        expect(capitalize('debuff')).toBe('Debuff');
        expect(capitalize('aura')).toBe('Aura');
    });

    it('handles empty or undefined string', () => {
        expect(capitalize('')).toBe('');
        expect(capitalize(undefined as any)).toBe('');
    });
});

describe('formatEffectTimer', () => {
    it('formats durations in minutes when >= 60 seconds', () => {
        expect(formatEffectTimer(180)).toBe('3m');
        expect(formatEffectTimer(120)).toBe('2m');
        expect(formatEffectTimer(90)).toBe('1m');
        expect(formatEffectTimer(60)).toBe('1m');
    });

    it('formats durations in seconds when < 60 seconds', () => {
        expect(formatEffectTimer(59)).toBe('59');
        expect(formatEffectTimer(30)).toBe('30');
        expect(formatEffectTimer(1)).toBe('1');
        expect(formatEffectTimer(0)).toBe('0');
    });

    it('clamps negative values to 0', () => {
        expect(formatEffectTimer(-5)).toBe('0');
    });
});



