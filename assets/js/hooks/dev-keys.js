/**
 * Debug builds only: relays every key pressed outside a text field, so the server can spot a
 * sequence (`adena`, `night`, `day`, Ctrl+C twice) and anything between breaks it. A letter goes
 * as itself, a Ctrl chord as `ctrl+<letter>`, the rest as `other`; a modifier alone is not a key.
 * The server keeps the keys and decides, and a release never draws the element this mounts on.
 */
const MODIFIERS = ['Control', 'Shift', 'Alt', 'Meta', 'CapsLock'];

export const DevKeys = {
    mounted() {
        this.onKeyDown = (e) => {
            const tag = e.target?.tagName;
            if (e.repeat || tag === 'INPUT' || tag === 'TEXTAREA' || MODIFIERS.includes(e.key))
                return;

            const letter = /^[a-z]$/i.test(e.key ?? '') ? e.key.toLowerCase() : null;
            const key = !letter || e.altKey || e.metaKey ? 'other'
                : e.ctrlKey ? `ctrl+${letter}` : letter;
            this.pushEvent('key', { key });
        };
        window.addEventListener('keydown', this.onKeyDown);
    },
    destroyed() {
        window.removeEventListener('keydown', this.onKeyDown);
    },
};
