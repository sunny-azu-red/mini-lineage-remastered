import { keep } from './kept';

/**
 * Keeps the sort a table's header was patched to, under `table:<id>`. Only a change is written,
 * never what a mount finds: a second tab opening on an older sort must not overwrite the one chosen
 * since. The server orders the rows, so it is handed every kept sort as the socket connects.
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
