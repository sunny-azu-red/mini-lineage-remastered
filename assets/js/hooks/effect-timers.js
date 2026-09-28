/**
 * An effect's remaining time, as the icon wears it. Twinned with `Format.countdown/1`; both are
 * held to test/fixtures/effect_timer.json so the label cannot change shape when this takes over.
 */
export function timerLabel(remainingMs) {
    const seconds = Math.max(0, Math.ceil(remainingMs / 1000));

    return seconds >= 60 ? `${Math.floor(seconds / 60)}m` : String(seconds);
}

/** The same time said in a sentence rather than on a badge. Twinned with `Format.remaining/1`. */
export function remainingLabel(remainingMs) {
    const seconds = Math.max(0, Math.ceil(remainingMs / 1000));
    const minutes = Math.floor(seconds / 60), rest = seconds % 60;

    if (!minutes) return `${rest}s`;

    return rest ? `${minutes}m ${rest}s` : `${minutes}m`;
}

/** Counts each effect down locally. The server sends a DURATION, so no two clocks are compared. */
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
    // Ticks only while there is a timer to count: most pages, Game Start among them, have none.
    stamp() {
        this.stampedAt = Date.now();
        const timing = this.el.querySelector('[data-remaining-ms]') !== null;
        if (timing && !this.interval) this.interval = setInterval(() => this.paint(), 1000);
        if (!timing && this.interval) this.interval = clearInterval(this.interval);
        this.paint();
    },
    // Every timed element carries its duration and a [data-timer] to write it into; the badge over
    // an emoji and the clause at the end of a sentence say the same time two ways.
    paint() {
        const elapsed = Date.now() - this.stampedAt;
        for (const icon of this.el.querySelectorAll('[data-remaining-ms]')) {
            const label = icon.querySelector('[data-timer]');
            const say = label.dataset.timer === 'long' ? remainingLabel : timerLabel;
            label.textContent = say(Number(icon.dataset.remainingMs) - elapsed);
        }
    },
};
