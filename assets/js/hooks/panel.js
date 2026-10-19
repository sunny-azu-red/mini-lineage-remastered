import { keep, recall } from './kept';

/**
 * A panel that folds on its own header. The server draws it folded and leaves `aria-expanded` to
 * this hook after that, so a patch never touches the reader's fold.
 */
export const Panel = {
    mounted() {
        this.toggle = this.el.querySelector(':scope > .panel-heading > .panel-toggle');
        // Open unless the reader folded it.
        this.show(recall('panel', this.el.id) !== '0');

        this.toggle.addEventListener('click', () => {
            this.show(!this.open);
            keep('panel', this.el.id, this.open ? '1' : '0');
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
