/**
 * Eases the HP/XP/Adena counters toward their new value, shimmering a bar that GAINED — damage
 * never does. Only intermediate frames are formatted here; the last one is the server's own text.
 */
const EASE_MS = 600;

const groupDigits = (n) => Math.round(n).toLocaleString('en-US');

function shortenAdena(value, trimTenth) {
    const abs = Math.abs(value);
    const sign = value < 0 ? '-' : '';
    if (abs <= 999)
        return String(Math.round(value));

    const short = (divisor, unit) => {
        const figure = (Math.floor((abs / divisor) * 10) / 10).toFixed(1);

        return sign + (trimTenth ? figure.replace('.0', '') : figure) + unit;
    };

    if (abs < 1e6) return short(1e3, 'k');
    if (abs < 1e9) return short(1e6, 'kk');
    return short(1e9, 'kkk');
}

/** How a purse is written. Twinned with `Format.adena`, and held to a table by both suites. */
export const shortAdena = (value) => shortenAdena(value, true);

/**
 * Mid-count, keeping the tenth the settled figure drops: "2.0k" becoming "2k" and back throws the
 * line left and right. The count always lands on the server's own rendering.
 */
const countingAdena = (value) => shortenAdena(value, false);

export const AnimatedValues = {
    mounted() {
        this.previous = new Map();
        // One handle per value, not one for the hook, or every chain but the last would run on.
        this.frames = new Map();
        this.sync(false);
    },
    updated() {
        this.sync(true);
    },
    destroyed() {
        for (const frame of this.frames.values()) cancelAnimationFrame(frame);
    },
    sync(animate) {
        // A bar that went round — XP into the next level — would slide backwards through the gap.
        // Snap it to zero with the transition off for one frame, then let it fill from there.
        const turns = new Map();
        for (const bar of this.el.querySelectorAll('.bar[data-wraps]')) {
            const turn = bar.dataset.wraps;
            if (animate && this.turns?.has(bar.id) && this.turns.get(bar.id) !== turn) {
                const width = bar.style.width;
                bar.style.transition = 'none';
                bar.style.width = '0%';
                requestAnimationFrame(() => {
                    bar.style.transition = '';
                    bar.style.width = width;
                });
            }
            turns.set(bar.id, turn);
        }
        this.turns = turns;

        const live = new Set();

        for (const el of this.el.querySelectorAll('[data-value]')) {
            const key = el.dataset.key;
            const target = Number(el.dataset.value);
            const from = this.previous.get(key);
            live.add(key);
            this.previous.set(key, target);

            if (!animate || from === undefined || from === target || !Number.isFinite(target))
                continue;

            if (target > from)
                this.shimmer(el);

            this.count(key, el, from, target);
        }

        // A figure that left the page is forgotten, so coming back counts from nothing stale.
        for (const key of this.previous.keys())
            if (!live.has(key))
                this.previous.delete(key);
    },
    shimmer(el) {
        const bar = el.closest('.bar-track')?.querySelector('.bar');
        if (!bar)
            return;

        bar.classList.remove('shimmer-active');
        // Force a reflow so a repeated gain restarts the sweep instead of being ignored.
        void bar.offsetWidth;
        bar.classList.add('shimmer-active');
        setTimeout(() => bar.classList.remove('shimmer-active'), 600);
    },
    count(key, el, from, to) {
        cancelAnimationFrame(this.frames.get(key));
        const format = el.dataset.format === 'adena' ? countingAdena : groupDigits;
        const settled = el.textContent;
        const started = performance.now();

        const step = (now) => {
            const t = Math.min(1, (now - started) / EASE_MS);
            const eased = 1 - Math.pow(1 - t, 3);

            if (t < 1) {
                el.textContent = format(from + (to - from) * eased);
                this.frames.set(key, requestAnimationFrame(step));
            } else {
                // Always ends on the server's own rendering, never this module's.
                el.textContent = settled;
                this.frames.delete(key);
            }
        };

        this.frames.set(key, requestAnimationFrame(step));
    },
};
