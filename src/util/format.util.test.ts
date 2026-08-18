import { describe, it, expect } from 'vitest';
import { formatAdena, formatNumber, pluralize, fillTemplate, slugify, formatShopItems, truncate } from './format.util';

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
                effect: { id: 'satisfied', type: 'buff', icon: '🥓', label: 'Satisfied', modifiers: [{ type: 'maxHealth', value: 10 }] }
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
            effect: { id: 'satisfied', type: 'buff', icon: '🥓', label: 'Satisfied', modifiers: [{ type: 'maxHealth', value: 10 }] },
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
