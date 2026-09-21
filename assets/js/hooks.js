import { playSound, setSoundEnabled, soundEnabled } from './soundfx';

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
 * An effect's remaining time, as the icon wears it. Twinned with `Format.countdown/1`; both are
 * held to test/fixtures/effect_timer.json so the label cannot change shape when this takes over.
 */
export function timerLabel(remainingMs) {
    const seconds = Math.max(0, Math.ceil(remainingMs / 1000));

    return seconds >= 60 ? `${Math.floor(seconds / 60)}m` : String(seconds);
}

/** Counts each effect down locally. The server sends a DURATION, so no two clocks are compared. */
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

            label.textContent = timerLabel(remaining - elapsed);
        }
    },
};

/**
 * Relays every non-repeated keydown outside a text field, which drives the Konami cheat. The
 * server keeps the buffer, so nothing here can be inspected to discover the sequence.
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
 * Focuses the panel's first control on arrival, so the game plays from the keyboard. Never takes
 * focus the player moved themselves, and never on the death screen, where Space would retire them.
 */
export const PanelFocus = {
    mounted() {
        this.screen = this.el.dataset.screen;
        // A click on a button is the player acting, and only an update that follows their own
        // action may take focus back. Cleared by the next focus pass, so it never outlives it.
        this.acted = false;
        this.el.addEventListener('click', (e) => {
            if (e.target.closest('button'))
                this.acted = true;
        });
        requestAnimationFrame(() => this.focusFirst(true));
    },
    updated() {
        const arrived = this.el.dataset.screen !== this.screen;
        this.screen = this.el.dataset.screen;
        // Deferred a frame: LiveView restores the previously-focused element after patching, so
        // claiming focus inline would be undone — and because it morphs one screen's control into
        // the next screen's, what it restores is the wrong control entirely.
        requestAnimationFrame(() => this.focusFirst(arrived));
    },
    focusFirst(arrived) {
        // You arrive here by dying, plausibly with a Space already travelling, and Play Again
        // would retire the run before it is read. Declining to focus is not enough: LiveView
        // morphs the Fight button into it and keeps focus there, so the panel must let go.
        if (this.el.dataset.screen === 'death') {
            if (this.el.contains(document.activeElement))
                document.activeElement.blur();

            return;
        }

        // Arriving pulls focus in. An update reclaims it only from nothing, or just after a press:
        // LiveView restores focus to that button, which on a shop left it on Order rather than the
        // picker. Anything you moved to yourself is left alone, so a tick never yanks it away.
        const acted = this.acted;
        this.acted = false;
        if (!arrived && document.activeElement !== document.body && !acted)
            return;

        // Links are out because Space scrolls them rather than activating them; hidden inputs
        // because they match `input` without being focusable; `.alert-dismiss` because it comes
        // before the screen's own content and would eat the first Space.
        const control = this.el.querySelector(
            'input:not([type="hidden"]), select, button:not(.alert-dismiss)',
        );
        if (control && !control.matches(':disabled'))
            control.focus({ preventScroll: true });
    },
};

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
    // A row sweeps when its stamp moves, which is any write at all: a purchase and a death move it
    // as surely as experience does, and somebody merely opening a tab never does.
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

// Blocked or private storage just means the panel opens where the template says, every time.
function recall(id) {
    try {
        return localStorage.getItem(`panel:${id}`);
    } catch {
        return null;
    }
}

function keep(id, open) {
    try {
        localStorage.setItem(`panel:${id}`, open ? '1' : '0');
    } catch {
        // Nothing to do: the panel will simply not remember.
    }
}

/**
 * A panel that does something: collapses on a click of its own header, and follows its content down
 * when it is a log rather than a document. Both are re-applied after every patch — the server
 * renders the panel's opening state from the template, and the reader's is newer than that.
 */
export const Panel = {
    mounted() {
        this.toggle = this.el.querySelector(':scope > .panel-toggle');
        this.sticky = this.el.dataset.stick === 'true';
        // A pin done on the frame the panel opens is only right for that frame. Anything that
        // reflows the list afterwards — a web font arriving, a scrollbar taking its width — moves
        // the bottom out from under it and leaves the box a pixel or so short of it. Following the
        // list's own size puts the question beyond timing.
        if (this.sticky)
            this.follow = new ResizeObserver(() => this.open && this.toBottom());

        // What the reader last did with THIS panel beats what the template opens it on. Keyed by
        // the panel's id, so the preference is about the panel and not about whose record it is.
        const kept = this.toggle && recall(this.el.id);
        this.open = !this.toggle
            || (kept === null ? this.toggle.getAttribute('aria-expanded') === 'true' : kept === '1');

        this.toggle?.addEventListener('click', () => {
            this.show(!this.open);
            keep(this.el.id, this.open);
            if (this.open) this.reveal();
        });
        this.show(this.open);

        // Two frames, so a paint has certainly happened: the chevron may only start animating once
        // the restored state is already on screen, or every refresh spins it into place.
        requestAnimationFrame(() =>
            requestAnimationFrame(() =>
                this.el.querySelector('.panel-arrow')?.setAttribute('data-ready', '')));
    },
    updated() {
        this.show(this.open);
    },
    destroyed() {
        this.follow?.disconnect();
    },
    // What a reader just opened should be on screen without them going to look for it — and it is
    // the BOTTOM that has to arrive, a log's newest lines being there. Only on a click: a panel
    // restored open, or one patched while open, was never asked to move the page.
    reveal() {
        const box = this.el.getBoundingClientRect();
        if (box.top >= 0 && box.bottom <= window.innerHeight) return;

        this.el.scrollIntoView({ behavior: 'smooth', block: 'end' });
    },
    show(open) {
        this.open = open;
        const body = this.body();
        if (this.toggle) {
            this.toggle.setAttribute('aria-expanded', String(open));
            body.hidden = !open;
        }

        if (!this.sticky) return;

        // A shut panel has nothing to watch and no height to scroll, so both wait for the way open.
        const list = body.firstElementChild;
        if (open && list) this.follow.observe(list);
        else this.follow.disconnect();
        if (open) this.toBottom();
    },
    body() {
        return this.el.querySelector(':scope > .panel-body');
    },
    toBottom() {
        const body = this.body();
        body.scrollTop = body.scrollHeight;

        // And then back onto its real end, for whatever fraction the display scale still leaves:
        // the clamp above is computed from a rounded `scrollHeight`, so it can sit past where the
        // content stops. Whole pixels are the list's job (`ol.chronicle li`); this is the rest.
        const last = body.firstElementChild?.lastElementChild;
        if (!last) return;

        const over = body.getBoundingClientRect().bottom - last.getBoundingClientRect().bottom;
        if (over > 0) body.scrollTop -= over;
    },
};

/**
 * Rewrites a server-rendered UTC stamp into the reader's own clock — the browser is the only thing
 * that knows it. Same shape as `Controls.short_date/1`, which stays as the no-JS fallback.
 */
export const LocalTime = {
    mounted() {
        this.render();
    },
    updated() {
        this.render();
    },
    render() {
        const at = new Date(this.el.dateTime);

        if (!isNaN(at)) this.el.textContent = localDate(at);
    },
};

function localDate(at) {
    const pad = (n) => String(n).padStart(2, '0');

    return `${pad(at.getDate())}/${pad(at.getMonth() + 1)}/${String(at.getFullYear()).slice(-2)}, `
        + `${pad(at.getHours())}:${pad(at.getMinutes())}`;
}

export const hooks = {
    SoundToggle, EffectTimers, KonamiRelay, PanelFocus, AnimatedValues, Panel, LocalTime,
};
