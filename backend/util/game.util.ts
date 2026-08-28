import { FlashMessage, PurchaseResult, Item, StatModifierType } from '@/interface';
import { randomInt } from '@/service/math.service';

export function randomElement<T>(array: readonly T[] | T[]): T {
    return array[randomInt(0, array.length - 1)];
}

export function makeFlash(text: string, type: FlashMessage['type'], sound?: string): FlashMessage {
    return {
        type,
        text: text.replace(/\n/g, '<br>'),
        sound,
    };
}

export function makePurchaseFlash(result: PurchaseResult, sound?: string): FlashMessage {
    return makeFlash(result.text, result.success ? 'success' : 'danger', result.success ? sound : undefined);
}

/**
 * Extracts a specific stat modifier value from an item
 * (from equipment `item.modifiers` or consumable `item.effect.modifiers`).
 */
export function getItemModifier(item: Item, stat: StatModifierType): number | undefined {
    const modifiers = item.modifiers ?? item.effect?.modifiers;

    return modifiers?.find(m => m.type === stat)?.value;
}
