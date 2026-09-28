/**
 * Focuses the panel's first control on arrival, so the game plays from the keyboard. Never takes
 * focus the player moved themselves, and never on the death screen, where Space would retire them.
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
        // You arrive here by dying, plausibly with a Space already travelling, and Play Again
        // would retire the run before it is read. Declining to focus is not enough: LiveView
        // morphs the Fight button into it and keeps focus there, so the panel must let go.
        if (this.el.dataset.screen === 'death') {
            if (this.el.contains(document.activeElement))
                document.activeElement.blur();

            return;
        }

        // Arriving pulls focus in, and so does your own press: LiveView restores focus to that
        // button, which on a shop left it on Order rather than the picker. Any other update is a
        // push you did not ask for, and wherever you left focus, nowhere included, stays yours.
        const acted = this.acted;
        this.acted = false;
        if (!arrived && !acted)
            return;

        // Links are out because Space scrolls them rather than activating them; hidden inputs
        // because they match `input` without being focusable; `.alert-dismiss` because it comes
        // before the screen's own content and would eat the first Space.
        const control = this.el.querySelector(
            'input:not([type="hidden"]), select, button:not(.alert-dismiss)',
        );
        if (control && !control.matches(':disabled'))
            control.focus({ preventScroll: true });
    },
};
