import { LOCALE, STAT_MODIFIER_CONFIG, SESSION_CONFIG } from '@/constant/game.constant';
import { formatAdena, formatNumber as formatNumberShared } from '@shared/format';
import { Item, StatModifier, StatModifierConfig } from '@/interface';

// Re-exported so backend callers have one import site; only what follows is backend-specific.
export { formatAdena, pluralize, fillTemplate, slugify, truncate, capitalize, formatEffectTimer } from '@shared/format';

export function formatNumber(num: number): string {
    return formatNumberShared(num, LOCALE);
}

export function formatShopItems(items: Item[]) {
    return items.map(i => ({
        ...i,
        modifiers: i.modifiers ?? i.effect?.modifiers ?? [],
        statFormatted: formatNumber(i.stat),
        costFormatted: formatAdena(i.cost),
    }));
}

export function formatEffectModifier(mod: StatModifier | { type: string; value: number; }): string {
    const config = (STAT_MODIFIER_CONFIG as Record<string, StatModifierConfig>)[mod.type];
    if (config?.isMultiplier)
        return `${mod.value}x ${config.label}`;

    const sign = mod.value > 0 ? '+' : '';
    const unit = config?.isPercentage ? '%' : '';
    const label = config ? ` ${config.label}` : ` ${mod.type}`;

    return `${sign}${mod.value}${unit}${label}`;
}

export function formatEffectTooltip(effect: { label: string; modifiers?: readonly StatModifier[] | StatModifier[] | readonly { type: string; value: number; }[]; }): string {
    if (!effect.modifiers || effect.modifiers.length === 0)
        return effect.label;

    return `${effect.label} (${effect.modifiers.map(formatEffectModifier).join(', ')})`;
}

export function formatSessionId(sessionId?: string, length: number = SESSION_CONFIG.shortIdLength): string {
    return sessionId ? sessionId.slice(0, length) : '-'.repeat(length);
}
