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
 * The same figure mid-count, keeping the tenth that the settled one drops. A tween across a round
 * thousand renders "2.0k" where the settled value says "2k", and those two characters vanishing
 * and coming back is what throws the line left and right. Nothing anybody reads for longer than a
 * frame: the count always lands on the server's own rendering.
 */
const countingAdena = (value) => shortenAdena(value, false);

export const AnimatedValues = {
    mounted() {
        this.previous = new Map();
        this.stamps = new Map();
        // One handle per value, not one for the hook: a board animates up to seventy-five at once,
        // and a single handle would leave every chain but the last running into a detached node.
        this.frames = new Map();
        // Delegated, so a table of rows costs one listener rather than one per row.
        this.el.addEventListener('animationend', (event) => {
            if (event.animationName === 'row-sweep') event.target.classList.remove('stirred');
        });
        this.sync(false);
    },
    updated() {
        this.sync(true);
    },
    destroyed() {
        for (const frame of this.frames.values()) cancelAnimationFrame(frame);
    },
    sync(animate) {
        // A level-up wraps xpCurrent DOWNWARD into the new level, so the bar would slide
        // backwards through the gap. Snap it to zero with the transition off for one frame, then
        // let it fill from there.
        const bar = this.el.querySelector('#xp-bar');
        const level = bar?.dataset.level;
        if (animate && bar && this.level !== undefined && level !== this.level) {
            const width = bar.style.width;
            bar.style.transition = 'none';
            bar.style.width = '0%';
            requestAnimationFrame(() => {
                bar.style.transition = '';
                bar.style.width = width;
            });
        }
        this.level = level;

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

        this.forget(this.previous, live);
        this.stir(animate);
    },
    // A board holds whoever is winning, so what a run was worth is remembered only while it is on
    // one. The sidebar's three keys never leave and this costs them nothing.
    forget(memory, live) {
        for (const key of memory.keys())
            if (!live.has(key))
                memory.delete(key);
    },
    // A row sweeps when its stamp moves: the Halls stamp a row with its last chronicle entry, so any
    // deed sweeps it and somebody merely opening a tab never does.
    stir(animate) {
        const live = new Set();

        for (const row of this.el.querySelectorAll('[data-stamp]')) {
            const key = row.dataset.key;
            const stamp = row.dataset.stamp;
            const before = this.stamps.get(key);
            live.add(key);
            this.stamps.set(key, stamp);

            if (!animate || before === undefined || before === stamp)
                continue;

            row.classList.remove('stirred');
            // Force a reflow so a second write restarts the sweep instead of being ignored.
            void row.offsetWidth;
            row.classList.add('stirred');
        }

        this.forget(this.stamps, live);
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
