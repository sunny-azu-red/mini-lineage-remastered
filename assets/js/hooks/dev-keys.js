/**
 * Debug builds only: relays each letter typed outside a text field, so typing `adena` can fill a
 * purse. The server keeps the letters and decides; a release never draws the element this mounts on.
 */
export const DevKeys = {
    mounted() {
        this.onKeyDown = (e) => {
            const tag = e.target?.tagName;
            if (e.repeat || !/^[a-z]$/i.test(e.key ?? '') || tag === 'INPUT' || tag === 'TEXTAREA')
                return;

            this.pushEvent('key', { key: e.key.toLowerCase() });
        };
        window.addEventListener('keydown', this.onKeyDown);
    },
    destroyed() {
        window.removeEventListener('keydown', this.onKeyDown);
    },
};
