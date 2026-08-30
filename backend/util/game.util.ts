import { FlashMessage, PurchaseResult, Item, StatModifierType } from '@/interface';
import { randomInt } from '@/service/math.service';

export function randomElement<T>(array: readonly T[] | T[]): T {
    return array[randomInt(0, array.length - 1)];
}

export function makeFlash(text: string, type: FlashMessage['type'], sound?: string): FlashMessage {
    return { type, text: text.replace(/\n/g, '<br>'), sound };
}

export function makePurchaseFlash(result: PurchaseResult, sound?: string): FlashMessage {
    return makeFlash(result.text, result.success ? 'success' : 'danger', result.success ? sound : undefined);
}

/** Reads a stat modifier off equipment (`item.modifiers`) or a consumable (`item.effect.modifiers`). */
export function getItemModifier(item: Item, stat: StatModifierType): number | undefined {
    return (item.modifiers ?? item.effect?.modifiers)?.find(m => m.type === stat)?.value;
}
