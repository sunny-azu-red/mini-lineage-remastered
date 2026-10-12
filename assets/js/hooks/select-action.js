/**
 * A dropdown's list stays open until the player closes it. LiveView refocuses the focused element
 * after every patch, a regen tick's included, and on Windows a `focus()` on a select that already has
 * it shuts an open list; it changes nothing else, so it is skipped.
 */
export const SelectAction = {
    mounted() {
        const focus = this.el.focus;
        this.el.focus = (options) => {
            if (document.activeElement !== this.el)
                focus.call(this.el, options);
        };
    },
};
