import { keep } from './kept';

/**
 * Keeps a remembered table's sort under `table:<id>`, writing only a change: a second tab mounting
 * on an older sort must not overwrite a newer one. `app.js` hands every kept sort over on connect.
 */
export const Table = {
    mounted() {
        this.sort = this.el.dataset.sort;
    },
    updated() {
        const sort = this.el.dataset.sort;
        if (sort === this.sort) return;

        this.sort = sort;
        keep('table', this.el.dataset.table, sort || null);
    },
};
