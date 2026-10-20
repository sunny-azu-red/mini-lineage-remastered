import { keep } from './kept';

/**
 * A panel that folds on its own header. The server draws the reader's kept fold and leaves
 * `aria-expanded` to this hook after that, so a patch never touches it; a click is kept and told to
 * the server, which draws the panel that way when it comes back on this visit.
 */
export const Panel = {
    mounted() {
        this.toggle = this.el.querySelector(':scope > .panel-heading > .panel-toggle');
        this.open = this.toggle.getAttribute('aria-expanded') === 'true';

        this.toggle.addEventListener('click', () => {
            this.show(!this.open);
            keep('panel', this.el.id, this.open ? '1' : '0');
            this.pushEvent('fold', { panel: this.el.id, open: this.open });
            if (this.open) this.reveal();
        });

        // Two frames, so a paint has certainly happened: the chevron may only start animating once
        // the restored state is already on screen, or every refresh spins it into place.
        requestAnimationFrame(() =>
            requestAnimationFrame(() =>
                this.el.querySelector('.panel-arrow')?.setAttribute('data-ready', '')));
    },
    // What a reader just opened should be on screen without them going to look for it. Only on a
    // click: a panel restored open, or one patched while open, was never asked to move the page.
    reveal() {
        const box = this.el.getBoundingClientRect();
        if (box.top >= 0 && box.bottom <= window.innerHeight) return;

        this.el.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
    },
    // The fold is `aria-expanded` alone, and the stylesheet hides a folded body.
    show(open) {
        this.open = open;
        this.toggle.setAttribute('aria-expanded', String(open));
    },
};
