/**
 * Counts an effect's time down where it is shown. The server sends a duration, never a deadline, so
 * the browser's clock is never compared with the server's.
 */
const secondsLeft = (ms) => Math.max(0, Math.ceil(ms / 1000));

/** Over an icon: "37", "2m", then "3h". Twinned with `Format.countdown`, held to a table by both suites. */
export function timerLabel(ms) {
    const seconds = secondsLeft(ms);
    if (seconds >= 3600) return `${Math.floor(seconds / 3600)}h`;
    return seconds >= 60 ? `${Math.floor(seconds / 60)}m` : String(seconds);
}

/** In a sentence: "1m 37s", then from an hour "3h". Twinned with `Format.remaining`, held to a table by both suites. */
export function remainingLabel(ms) {
    const seconds = secondsLeft(ms);
    const hours = Math.floor(seconds / 3600);
    const minutes = Math.floor((seconds % 3600) / 60), rest = seconds % 60;

    if (hours) return `${hours}h`;
    if (!minutes) return `${rest}s`;
    return rest ? `${minutes}m ${rest}s` : `${minutes}m`;
}

// When each countdown ends by this page's own clock, by `data-timer-key`. Only the first duration
// counts: a later one is measured by a server clock that may have stepped since, and a badge and its
// row read one end, so they turn over together.
const ends = new Map();

const endOf = (timer, now) => {
    const key = timer.dataset.timerKey;
    if (!ends.has(key)) ends.set(key, now + Number(timer.dataset.remainingMs));
    return ends.get(key);
};

export const EffectTimers = {
    mounted() {
        this.paint();
    },
    updated() {
        this.paint();
    },
    destroyed() {
        clearTimeout(this.timeout);
    },
    // Repaints as the soonest label turns over, not a second after whenever it was drawn. An aura
    // held indefinitely, In Combat on the ground among them, has no end to count to.
    paint() {
        clearTimeout(this.timeout);
        const now = performance.now();
        let next = Infinity;
        for (const timer of this.el.querySelectorAll('[data-remaining-ms]')) {
            const left = endOf(timer, now) - now;
            const say = timer.dataset.timer === 'long' ? remainingLabel : timerLabel;
            timer.textContent = say(left);
            if (left > 0) next = Math.min(next, left % 1000 || 1000);
        }
        for (const [key, end] of ends) if (end < now - 60_000) ends.delete(key);
        if (next < Infinity) this.timeout = setTimeout(() => this.paint(), next + 5);
    },
};
