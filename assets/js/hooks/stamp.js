/**
 * When something happened, aged where it is shown. The server sends an age, never an instant to
 * compare with this page's clock, and the date it turns into past the cap, already in the game's
 * zone, so only the age is worked out here.
 */
const MINUTE = 60_000, HOUR = 3_600_000, DAY = 86_400_000;

function ago(n, unit, word, form) {
    if (form === 'short') return `${n}${unit} ago`;
    if (n === 1) return word === 'hour' ? 'an hour ago' : `a ${word} ago`;
    return `${n} ${word}s ago`;
}

/** "3m ago", then the date. Twinned with `Format.stamp`, held to a table by both suites. */
export function stampLabel(ageMs, capMs, form, date) {
    if (ageMs >= capMs) return date;
    if (ageMs < MINUTE) return 'just now';
    if (ageMs < HOUR) return ago(Math.floor(ageMs / MINUTE), 'm', 'minute', form);
    if (ageMs < DAY) return ago(Math.floor(ageMs / HOUR), 'h', 'hour', form);
    return ago(Math.floor(ageMs / DAY), 'd', 'day', form);
}

// When each stamp happened by this page's own clock, by its instant. Only the first age counts: a
// later one is measured by a server clock that may have stepped since.
const births = new Map();

export const Stamp = {
    mounted() {
        this.paint();
    },
    updated() {
        this.paint();
    },
    destroyed() {
        clearTimeout(this.timeout);
        births.delete(this.el.dateTime);
    },
    // Repaints as the label turns over, and never again once it is a date.
    paint() {
        clearTimeout(this.timeout);
        const el = this.el, now = performance.now();
        if (!births.has(el.dateTime)) births.set(el.dateTime, now - Number(el.dataset.ageMs));
        const age = now - births.get(el.dateTime), cap = Number(el.dataset.capMs);
        const label = stampLabel(age, cap, el.dataset.form, el.dataset.date);
        if (el.textContent !== label) el.textContent = label;
        if (age >= cap) return;
        const unit = age < HOUR ? MINUTE : age < DAY ? HOUR : DAY;
        const next = Math.min(unit - (Math.max(age, 0) % unit), cap - age);
        this.timeout = setTimeout(() => this.paint(), next + 5);
    },
};
