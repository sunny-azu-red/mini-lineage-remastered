import { Log } from './log';
import { keep, recall } from './kept';

/**
 * A panel that does something: folds on a click of its own header, and is a log when it says so,
 * which `Log` does. Both are re-applied after every patch — the server renders the panel's opening
 * state from the template, and the reader's is newer than that.
 */
export const Panel = {
    mounted() {
        this.toggle = this.el.querySelector(':scope > .panel-toggle');
        this.remember = this.el.dataset.remember !== 'false';
        this.start();
        this.log = this.el.dataset.log ? new Log(this) : null;

        this.toggle?.addEventListener('click', () => {
            if (!this.folds()) return;
            this.show(!this.open);
            if (this.remember) keep('panel', this.el.id, this.open ? '1' : '0');
            if (this.open) this.reveal();
        });
        // Where the panel may fold is the stylesheet's to say, and it can change with the width.
        this.onResize = () => this.show(this.open);
        window.addEventListener('resize', this.onResize);

        // Two frames, so a paint has certainly happened: the chevron may only start animating once
        // the restored state is already on screen, or every refresh spins it into place.
        requestAnimationFrame(() =>
            requestAnimationFrame(() =>
                this.el.querySelector('.panel-arrow')?.setAttribute('data-ready', '')));
    },
    // What a mount decides, and what a new subject decides again: the same element can be patched
    // from one record's log to the next, and nothing about the last one's reading carries over.
    start() {
        this.subject = this.el.dataset.subject;
        // What the reader last did with THIS panel beats what the template opens it on, where the
        // panel keeps it. Keyed by the panel's id, so it is about the panel and not whose it is.
        const kept = this.toggle && this.remember ? recall('panel', this.el.id) : null;
        this.open = !this.toggle
            || (kept === null ? this.toggle.getAttribute('aria-expanded') === 'true' : kept === '1');
        this.show(this.open);
    },
    beforeUpdate() {
        this.log?.beforeUpdate();
    },
    updated() {
        if (this.el.dataset.subject !== this.subject) {
            this.start();
            return this.log?.start();
        }
        this.show(this.open);
        this.log?.updated();
    },
    destroyed() {
        window.removeEventListener('resize', this.onResize);
        this.log?.destroy();
    },
    // Whether this panel folds where it stands; a layout with room for it says 0.
    folds() {
        return !!this.toggle && getComputedStyle(this.el).getPropertyValue('--folds').trim() !== '0';
    },
    shown() {
        return this.open || !this.folds();
    },
    // What a reader just opened should be on screen without them going to look for it. Only on a
    // click: a panel restored open, or one patched while open, was never asked to move the page.
    reveal() {
        const box = this.el.getBoundingClientRect();
        if (box.top >= 0 && box.bottom <= window.innerHeight) return;

        this.el.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
    },
    // The fold is `aria-expanded` alone, and the stylesheet hides a folded body. Where the panel
    // cannot fold its header is no control at all, so it says nothing and takes no focus.
    show(open) {
        this.open = open;
        if (this.toggle) {
            const folds = this.folds();
            this.toggle.disabled = !folds;
            if (folds) this.toggle.setAttribute('aria-expanded', String(open));
            else this.toggle.removeAttribute('aria-expanded');
        }
        this.log?.showed();
    },
};
