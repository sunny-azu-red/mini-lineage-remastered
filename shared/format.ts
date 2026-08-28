/**
 * Pure, framework-agnostic formatting helpers shared by the server (backend/) and the
 * client (frontend/src/). Kept dependency-free (no `fs`, no game constants) so both
 * a Node process and a browser bundle can import this file unmodified.
 *
 * These mirror backend/util/format.util.ts's formatAdena/formatNumber/pluralize/
 * formatEffectTimer exactly (same output for the same input) — the server still
 * uses its own copy internally, but this is the one the client imports.
 */

export function formatAdena(adena: number): string {
    const abs = Math.abs(adena);
    const sign = adena < 0 ? '-' : '';

    if (abs <= 999)
        return adena.toString();

    const floorToOneDecimal = (divisor: number, unit: string) => {
        const calculated = Math.floor((abs / divisor) * 10) / 10;
        return sign + calculated.toFixed(1).replace('.0', '') + unit;
    };

    if (abs < 1_000_000)
        return floorToOneDecimal(1_000, 'k');
    if (abs < 1_000_000_000)
        return floorToOneDecimal(1_000_000, 'kk');

    return floorToOneDecimal(1_000_000_000, 'kkk');
}

export function formatNumber(num: number, locale: string = 'en-US'): string {
    return num.toLocaleString(locale);
}

export function pluralize(singular: string, plural: string, count: number, emoji?: string): string {
    const icon = emoji ? `${emoji} ` : '';
    if (count === 1) {
        const article = ['a', 'e', 'i', 'o', 'u'].includes(singular.charAt(0).toLowerCase()) ? 'an' : 'a';
        return `${article} ${icon}${singular}`;
    }

    return `${formatNumber(count)} ${icon}${plural}`;
}

export function formatEffectTimer(remSec: number): string {
    if (remSec >= 60)
        return `${Math.floor(remSec / 60)}m`;

    return `${Math.max(0, remSec)}`;
}

export function truncate(text: string, length: number): string {
    if (text.length <= length)
        return text;

    return text.substring(0, length) + '...';
}

export function slugify(text: string): string {
    return text.toString().toLowerCase().trim()
        .replace(/\s+/g, '-')
        .replace(/[^\w-]+/g, '')
        .replace(/--+/g, '-');
}

export function fillTemplate(template: string, data: Record<string, unknown>): string {
    if (!template)
        return '';

    const ternaryRegex = /\{(\w+)\s*\?\s*['"]([^'"]*)['"]\s*:\s*['"]([^'"]*)['"]\}/g;
    const processed = template.replace(ternaryRegex, (_, key, trueVal, falseVal) => {
        return data[key] ? trueVal : falseVal;
    });

    return processed.replace(/\{(\w+)\}/g, (_, key) => {
        const val = data[key];
        return val !== undefined && val !== null ? String(val) : `{${key}}`;
    });
}

export function capitalize(text: string): string {
    if (!text)
        return '';

    return text.charAt(0).toUpperCase() + text.slice(1);
}

/** Formats a highscore/db timestamp exactly as today's highscores.view.ts does: DD/MM/YY, HH:MM. */
export function formatShortDate(iso: string): string {
    const d = new Date(iso);
    const pad = (n: number) => n.toString().padStart(2, '0');
    return `${pad(d.getDate())}/${pad(d.getMonth() + 1)}/${d.getFullYear().toString().slice(-2)}, ${pad(d.getHours())}:${pad(d.getMinutes())}`;
}
