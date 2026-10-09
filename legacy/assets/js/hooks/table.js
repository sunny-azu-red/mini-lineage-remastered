import { keep } from './kept';

/**
 * Keeps a table's sort under `table:<id>`, writing only a change: a second tab mounting on an older
 * sort must not overwrite a newer one. The server is handed every kept sort as the socket connects.
 */
export const Table = {
    mounted() {
        this.sort = this.el.dataset.sort ?? '';
    },
    updated() {
        const sort = this.el.dataset.sort ?? '';
        if (sort === this.sort) return;

        this.sort = sort;
        if (this.el.dataset.remember !== 'false') keep('table', this.el.dataset.table, sort || null);
    },
};
