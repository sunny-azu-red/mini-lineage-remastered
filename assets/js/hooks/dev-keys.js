/**
 * Debug builds only: relays each letter typed outside a text field, and Ctrl+C, so the server can
 * spot a sequence (`adena`, `night`, `day`, Ctrl+C twice). The server keeps the keys and decides; a
 * release never draws the element this mounts on. Ctrl+C still copies: nothing is prevented.
 */
export const DevKeys = {
    mounted() {
        this.onKeyDown = (e) => {
            const tag = e.target?.tagName;
            const key = (e.key ?? '').toLowerCase();
            if (e.repeat || tag === 'INPUT' || tag === 'TEXTAREA' || e.altKey || e.metaKey)
                return;

            if (e.ctrlKey && key === 'c')
                this.pushEvent('key', { key: 'ctrl+c' });
            else if (!e.ctrlKey && /^[a-z]$/.test(key))
                this.pushEvent('key', { key });
        };
        window.addEventListener('keydown', this.onKeyDown);
    },
    destroyed() {
        window.removeEventListener('keydown', this.onKeyDown);
    },
};
