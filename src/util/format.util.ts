import { LOCALE, STAT_MODIFIER_CONFIG } from '@/constant/game.constant';
import { Item, StatModifier, StatModifierConfig } from '@/interface';

export function formatAdena(adena: number): string {
    const abs = Math.abs(adena);
    const sign = adena < 0 ? '-' : '';

    if (abs <= 999)
        return adena.toString();

    const floorToOneDecimal = (value: number, divisor: number, unit: string) => {
        const calculated = Math.floor((abs / divisor) * 10) / 10;
        return sign + calculated.toFixed(1).replace('.0', '') + unit;
    };

    if (abs < 1_000_000) return floorToOneDecimal(abs, 1_000, 'k');
    if (abs < 1_000_000_000) return floorToOneDecimal(abs, 1_000_000, 'kk');

    return floorToOneDecimal(abs, 1_000_000_000, 'kkk');
}

export function formatNumber(num: number): string {
    return num.toLocaleString(LOCALE);
}

export function pluralize(singular: string, plural: string, count: number, emoji?: string): string {
    const icon = emoji ? `${emoji} ` : '';
    if (count === 1) {
        const article = ['a', 'e', 'i', 'o', 'u'].includes(singular.charAt(0).toLowerCase()) ? 'an' : 'a';
        return `${article} ${icon}${singular}`;
    }
    return `${formatNumber(count)} ${icon}${plural}`;
}

export function formatShopItems(items: Item[]) {
    return items.map(i => ({
        ...i,
        modifiers: i.modifiers ?? i.effect?.modifiers ?? [],
        statFormatted: formatNumber(i.stat),
        costFormatted: formatAdena(i.cost),
    }));
}

export function fillTemplate(template: string, data: Record<string, any>): string {
    if (!template)
        return '';

    // process ternaries: {condition ? 'trueVal' : 'falseVal'} or {condition ? "trueVal" : "falseVal"}
    const ternaryRegex = /\{(\w+)\s*\?\s*['"]([^'"]*)['"]\s*:\s*['"]([^'"]*)['"]\}/g;
    let processed = template.replace(ternaryRegex, (_, key, trueVal, falseVal) => {
        return data[key] ? trueVal : falseVal;
    });

    // process variables: {variable}
    return processed.replace(/\{(\w+)\}/g, (_, key) => {
        const val = data[key];
        return val !== undefined && val !== null ? val.toString() : `{${key}}`;
    });
}

export function slugify(text: string): string {
    return text.toString().toLowerCase().trim()
        .replace(/\s+/g, '-')     // Replace spaces with -
        .replace(/[^\w-]+/g, '')  // Remove all non-word chars
        .replace(/--+/g, '-');    // Replace multiple - with single -
}

export function truncate(text: string, length: number): string {
    if (text.length <= length) return text;
    return text.substring(0, length) + '...';
}

export function formatEffectModifier(mod: StatModifier | { type: string; value: number; }): string {
    const config = (STAT_MODIFIER_CONFIG as Record<string, StatModifierConfig>)[mod.type];
    if (config?.isMultiplier) {
        return `${mod.value}x ${config.label}`;
    }
    const sign = mod.value > 0 ? '+' : '';
    const unit = config?.isPercentage ? '%' : '';
    const label = config ? ` ${config.label}` : ` ${mod.type}`;
    return `${sign}${mod.value}${unit}${label}`;
}

export function formatEffectTooltip(effect: { label: string; modifiers?: readonly StatModifier[] | StatModifier[] | readonly { type: string; value: number; }[]; }): string {
    if (!effect.modifiers || effect.modifiers.length === 0) {
        return effect.label;
    }
    const formattedMods = effect.modifiers.map(formatEffectModifier).join(', ');
    return `${effect.label} (${formattedMods})`;
}

export function formatSessionId(sessionId?: string, length: number = 7): string {
    if (!sessionId)
        return '-'.repeat(length);

    return sessionId.slice(0, length);
}

export function capitalize(text: string): string {
    if (!text)
        return '';

    return text.charAt(0).toUpperCase() + text.slice(1);
}
