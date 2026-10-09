/**
 * Focuses the panel's first control on arrival, so the game plays from the keyboard. Never takes
 * focus the player moved themselves.
 */
export const PanelFocus = {
    mounted() {
        this.screen = this.el.dataset.screen;
        // A click on a button is the player acting, and only an update that follows their own
        // action may take focus back. Cleared by the next focus pass, so it never outlives it.
        this.acted = false;
        this.el.addEventListener('click', (e) => {
            if (e.target.closest('button'))
                this.acted = true;
        });
        requestAnimationFrame(() => this.focusFirst(true));
    },
    updated() {
        const arrived = this.el.dataset.screen !== this.screen;
        this.screen = this.el.dataset.screen;
        // Deferred a frame: LiveView restores the previously-focused element after patching, so
        // claiming focus inline would be undone — and because it morphs one screen's control into
        // the next screen's, what it restores is the wrong control entirely.
        requestAnimationFrame(() => this.focusFirst(arrived));
    },
    focusFirst(arrived) {
        // Arriving pulls focus in, and so does your own press, which LiveView would restore to that
        // button. Any other update is a push you did not ask for, and focus stays where you left it.
        const acted = this.acted;
        this.acted = false;
        if (!arrived && !acted)
            return;

        // Links are out because Space scrolls them rather than activating them; hidden inputs
        // because they match `input` without being focusable; and anything that destroys, by its mark.
        const control = this.el.querySelector(
            'input:not([type="hidden"]), select, button:not([data-no-autofocus])',
        );
        if (control && !control.matches(':disabled'))
            control.focus({ preventScroll: true });
    },
};
