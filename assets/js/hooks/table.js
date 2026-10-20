import { keep } from './kept';

/**
 * Keeps a remembered table's sort under `table:<id>`, writing only a change: a second tab mounting
 * on an older sort must not overwrite a newer one. The server reads it back for its first draw.
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
