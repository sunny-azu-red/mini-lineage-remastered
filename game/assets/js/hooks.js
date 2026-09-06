import { playSound, setSoundEnabled, soundEnabled, restoreSoundPreference } from './soundfx';

/** Mute toggle. The preference is per-browser and never reaches the server. */
export const SoundToggle = {
    mounted() {
        this.render();
        this.el.addEventListener('click', () => {
            const willEnable = !soundEnabled();
            setSoundEnabled(willEnable);
            this.render();
            // A chime confirms only when the click is ENABLING sound.
            if (willEnable)
                playSound('buy');
        });
    },
    render() {
        const on = soundEnabled();
        const title = on ? 'Sound FX Enabled (Click to Mute)' : 'Sound FX Muted (Click to Unmute)';
        this.el.className = `sound-toggle-btn${on ? '' : ' muted'}`;
        this.el.title = title;
        this.el.setAttribute('aria-label', title);
        this.el.textContent = on ? '🔊' : '🔇';
    },
};

/**
 * Counts each effect's timer down locally. The server sends a DURATION, not a deadline, so the
 * two clocks are never compared — this only subtracts elapsed local time from what it was told.
 */
export const EffectTimers = {
    mounted() {
        this.stamp();
        this.interval = setInterval(() => this.paint(), 1000);
    },
    updated() {
        this.stamp();
    },
    destroyed() {
        clearInterval(this.interval);
    },
    stamp() {
        this.stampedAt = Date.now();
        this.paint();
    },
    paint() {
        const elapsed = Date.now() - this.stampedAt;
        for (const icon of this.el.querySelectorAll('[data-remaining-ms]')) {
            const remaining = Number(icon.dataset.remainingMs);
            if (!Number.isFinite(remaining))
                continue;

            const label = icon.querySelector('.effect-timer');
            if (!label)
                continue;

            const seconds = Math.max(0, Math.ceil((remaining - elapsed) / 1000));
            label.textContent = seconds >= 60 ? `${Math.floor(seconds / 60)}m` : String(seconds);
        }
    },
};

/**
 * Relays every non-repeated keydown outside a text field to the server, which drives the Konami
 * cheat. Deliberately fire-and-forget: the server keeps the buffer, so nothing here can be
 * inspected to discover the sequence.
 */
export const KonamiRelay = {
    mounted() {
        this.onKeyDown = (e) => {
            const tag = e.target?.tagName;
            // INPUT and TEXTAREA only, matching the reference: a focused <select> still relays,
            // even though the arrow keys also move its selection.
            if (!e.key || e.repeat || tag === 'INPUT' || tag === 'TEXTAREA')
                return;

            this.pushEvent('key', { key: e.key.toLowerCase() });
        };
        window.addEventListener('keydown', this.onKeyDown);
    },
    destroyed() {
        window.removeEventListener('keydown', this.onKeyDown);
    },
};

/**
 * Focuses the main panel's first control on arrival, so the game plays from the keyboard. Never
 * steals focus from a control the player moved to themselves, and never focuses on the death
 * screen, where a stray keypress would submit a score or wipe the character.
 */
export const PanelFocus = {
    mounted() {
        this.focusFirst();
    },
    updated() {
        this.focusFirst();
    },
    focusFirst() {
        if (this.el.dataset.screen === 'death')
            return;

        const active = document.activeElement;
        if (active && active !== document.body && this.el.contains(active))
            return;

        const control = this.el.querySelector('input, select, button, a.btn');
        if (control)
            control.focus({ preventScroll: true });
    },
};

/**
 * Eases the HP/XP/Adena counters toward their new value and sweeps a shimmer across a bar that
 * GAINED — damage never shimmers.
 *
 * Only the intermediate frames are formatted here. The final value is always the server-rendered
 * text this hook was handed, so a difference between the two formatters can never be read.
 */
const EASE_MS = 600;

const groupDigits = (n) => Math.round(n).toLocaleString('en-US');

function shortAdena(value) {
    const abs = Math.abs(value);
    const sign = value < 0 ? '-' : '';
    if (abs <= 999)
        return String(Math.round(value));

    const short = (divisor, unit) =>
        sign + (Math.floor((abs / divisor) * 10) / 10).toFixed(1).replace('.0', '') + unit;

    if (abs < 1e6) return short(1e3, 'k');
    if (abs < 1e9) return short(1e6, 'kk');
    return short(1e9, 'kkk');
}

export const AnimatedValues = {
    mounted() {
        this.previous = new Map();
        this.sync(false);
    },
    updated() {
        this.sync(true);
    },
    destroyed() {
        cancelAnimationFrame(this.frame);
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

        for (const el of this.el.querySelectorAll('[data-value]')) {
            const key = el.dataset.key;
            const target = Number(el.dataset.value);
            const from = this.previous.get(key);
            this.previous.set(key, target);

            if (!animate || from === undefined || from === target || !Number.isFinite(target))
                continue;

            if (target > from)
                this.shimmer(el);

            this.count(el, from, target);
        }
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
    count(el, from, to) {
        const format = el.dataset.format === 'adena' ? shortAdena : groupDigits;
        const settled = el.textContent;
        const started = performance.now();

        const step = (now) => {
            const t = Math.min(1, (now - started) / EASE_MS);
            const eased = 1 - Math.pow(1 - t, 3);

            if (t < 1) {
                el.textContent = format(from + (to - from) * eased);
                this.frame = requestAnimationFrame(step);
            } else {
                // Always ends on the server's own rendering, never this module's.
                el.textContent = settled;
            }
        };

        this.frame = requestAnimationFrame(step);
    },
};

export const hooks = { SoundToggle, EffectTimers, KonamiRelay, PanelFocus, AnimatedValues };
