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

export const hooks = { SoundToggle, EffectTimers, KonamiRelay, PanelFocus };
