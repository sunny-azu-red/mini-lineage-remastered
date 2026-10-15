/**
 * Counts an effect's time down where it is shown. The server sends a duration, never a deadline, so
 * the browser's clock is never compared with the server's. A patch can carry the duration measured
 * at an earlier build, so a timer restarts only when its duration changes.
 */
const secondsLeft = (ms) => Math.max(0, Math.ceil(ms / 1000));

/** Over an icon: "37", then "2m". Twinned with `Format.countdown`, held to a table by both suites. */
export function timerLabel(ms) {
    const seconds = secondsLeft(ms);
    return seconds >= 60 ? `${Math.floor(seconds / 60)}m` : String(seconds);
}

/** In a sentence: "1m 37s". Twinned with `Format.remaining`, held to a table by both suites. */
export function remainingLabel(ms) {
    const seconds = secondsLeft(ms);
    const minutes = Math.floor(seconds / 60), rest = seconds % 60;

    if (!minutes) return `${rest}s`;
    return rest ? `${minutes}m ${rest}s` : `${minutes}m`;
}

export const EffectTimers = {
    mounted() {
        this.stamp();
    },
    updated() {
        this.stamp();
    },
    destroyed() {
        clearInterval(this.interval);
    },
    // Ticks only while something here is timed: an aura held indefinitely, In Combat on the ground
    // among them, has no end to count to.
    stamp() {
        const now = Date.now();
        for (const timer of this.el.querySelectorAll('[data-remaining-ms]')) {
            if (timer.stampedMs === timer.dataset.remainingMs) continue;
            timer.stampedMs = timer.dataset.remainingMs;
            timer.stampedAt = now;
        }
        clearInterval(this.interval);
        this.interval = this.el.querySelector('[data-remaining-ms]')
            ? setInterval(() => this.paint(), 1000)
            : undefined;
        this.paint();
    },
    paint() {
        for (const timer of this.el.querySelectorAll('[data-remaining-ms]')) {
            const say = timer.dataset.timer === 'long' ? remainingLabel : timerLabel;
            timer.textContent = say(Number(timer.dataset.remainingMs) - (Date.now() - timer.stampedAt));
        }
    },
};
