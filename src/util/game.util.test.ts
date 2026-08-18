import { describe, it, expect } from 'vitest';
import { makeFlash, makePurchaseFlash, getItemModifier, randomElement } from './game.util';

describe('randomElement', () => {
    it('picks an element from an array', () => {
        const arr = ['a', 'b', 'c'];
        expect(arr).toContain(randomElement(arr));
    });
});

describe('makeFlash', () => {
    it('converts newlines to <br>', () => {
        const flash = makeFlash('line1\nline2', 'info');
        expect(flash.text).toBe('line1<br>line2');
    });
    it('forwards the type', () => {
        expect(makeFlash('msg', 'danger').type).toBe('danger');
    });
});

describe('makePurchaseFlash', () => {
    it('returns success type on success', () => {
        const flash = makePurchaseFlash({ success: true, text: 'bought!' });
        expect(flash.type).toBe('success');
    });
    it('returns danger type on failure', () => {
        const flash = makePurchaseFlash({ success: false, text: 'not enough adena' });
        expect(flash.type).toBe('danger');
    });
});

describe('getItemModifier', () => {
    it('returns crit from weapon item modifiers', () => {
        const weapon: any = { id: 1, name: 'Blade', stat: 45, cost: 1000, modifiers: [{ type: 'crit', value: 5 }] };
        expect(getItemModifier(weapon, 'crit')).toBe(5);
        expect(getItemModifier(weapon, 'regen')).toBeUndefined();
        expect(getItemModifier(weapon, 'maxHealth')).toBeUndefined();
    });

    it('returns regen from armor item modifiers', () => {
        const armor: any = { id: 1, name: 'Plate', stat: 41, cost: 1000, modifiers: [{ type: 'regen', value: 2 }] };
        expect(getItemModifier(armor, 'regen')).toBe(2);
        expect(getItemModifier(armor, 'crit')).toBeUndefined();
        expect(getItemModifier(armor, 'maxHealth')).toBeUndefined();
    });

    it('returns maxHealth from food item effect', () => {
        const food: any = {
            id: 2,
            name: 'Sausage',
            stat: 15,
            cost: 29,
            effect: {
                id: 'satisfied',
                type: 'buff',
                icon: '🥓',
                label: 'Satisfied',
                modifiers: [{ type: 'maxHealth', value: 10 }]
            }
        };
        expect(getItemModifier(food, 'maxHealth')).toBe(10);
        expect(getItemModifier(food, 'regen')).toBeUndefined();
        expect(getItemModifier(food, 'crit')).toBeUndefined();
    });

    it('returns undefined when item has no modifier or effect', () => {
        const basicItem: any = { id: 0, name: 'Apple', stat: 6, cost: 11 };
        expect(getItemModifier(basicItem, 'maxHealth')).toBeUndefined();
        expect(getItemModifier(basicItem, 'crit')).toBeUndefined();
        expect(getItemModifier(basicItem, 'regen')).toBeUndefined();
    });
});
