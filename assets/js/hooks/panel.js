import { keep, recall } from './kept';

/**
 * A panel that folds on its own header, re-applied after every patch: the server renders the
 * template's opening state, and the reader's is newer.
 */
export const Panel = {
    mounted() {
        this.toggle = this.el.querySelector(':scope > .panel-toggle');
        // The reader's last fold beats the template's.
        const kept = this.toggle ? recall('panel', this.el.id) : null;
        this.open = !this.toggle
            || (kept === null ? this.toggle.getAttribute('aria-expanded') === 'true' : kept === '1');
        this.show(this.open);

        this.toggle?.addEventListener('click', () => {
            if (!this.folds()) return;
            this.show(!this.open);
            keep('panel', this.el.id, this.open ? '1' : '0');
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
    updated() {
        this.show(this.open);
    },
    destroyed() {
        window.removeEventListener('resize', this.onResize);
    },
    // Whether this panel folds where it stands; a layout with room for it says 0.
    folds() {
        return !!this.toggle && getComputedStyle(this.el).getPropertyValue('--folds').trim() !== '0';
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
    },
};
