import { useEffect } from 'react';
import type { ScreenId } from '@shared/contract';

/**
 * Form controls only, in DOM order. Links are excluded deliberately: Space scrolls a link rather
 * than activating it, so focusing one would arm a key that does nothing. `.alert-dismiss` is
 * NoticeAlert's `×`, which sits inside `.panel-body` BEFORE the screen's own content — without
 * this exclusion the first Space press after any error would dismiss the banner instead of
 * playing.
 */
const CONTROLS = 'input, select, button:not(.alert-dismiss)';

/**
 * The one screen that must never auto-focus. You arrive by dying — plausibly with a Space press
 * already travelling — and its first button is "📜 Write your Legacy!", or "Play Again?" for a run
 * that is not highscore-eligible. A stray press would submit the score before the death message
 * has been read, or restart the character and skip submission altogether.
 */
const NO_AUTOFOCUS: ReadonlySet<ScreenId> = new Set(['death']);

/**
 * Puts keyboard focus on the panel's first control, so the game is playable without a mouse:
 * Space repeats the Fight button, ↑↓ + Enter drives the shop and travel selects.
 *
 * Establishing focus is only half of it. `useAction` disables a button for the length of its
 * request, and a disabled element is not focusable — a real browser blurs it to `<body>`, so by
 * the time the ack re-enables the button, focus is gone and the next Space scrolls the page. The
 * MutationObserver is what closes that loop. It cannot be a dependency array: `pending` is local
 * state inside each screen component, so neither App nor AppShell re-renders at the moment the
 * button becomes focusable again. Watching for `disabled` also covers screen content arriving
 * after the first hydrate, for free.
 *
 * NOTE: jsdom does not blur a disabled element, so tests must call `.blur()` themselves to
 * reproduce what a browser does here.
 */
export function usePanelFocus(screen: ScreenId): void {
    useEffect(() => {
        if (NO_AUTOFOCUS.has(screen))
            return;

        // Scoped through `#main` because the sidebar's StatusPanel and InventoryPanel are
        // `.panel-body` too, and both precede the main panel in the DOM — an unscoped lookup
        // silently searches the stat rows, which hold no controls at all.
        //
        // Null when ErrorBoundary trips: it renders <ErrorScreen> bare, replacing AppShell.
        const panel = document.querySelector('#main .panel-body');
        if (!panel)
            return;

        const claim = (force: boolean) => {
            // On a screen change focus SHOULD follow the player into the new content, even out of
            // a header link they just clicked. On an in-screen mutation it must stay gentle, or it
            // would yank focus off a select they tabbed to, or out of the name field mid-word.
            if (!force && document.activeElement !== document.body)
                return;

            // Resolved unconditionally, then declined if disabled — NOT `:not(:disabled)` in the
            // selector. While the Fight button is mid-request the search must not run past it to
            // some other button and arm Space on the wrong action; it waits for the observer to
            // fire again when the real target comes back.
            const target = panel.querySelector<HTMLElement>(CONTROLS);
            if (target && !target.matches(':disabled'))
                target.focus();
        };

        claim(true);

        const observer = new MutationObserver(() => claim(false));
        observer.observe(panel, { childList: true, subtree: true, attributes: true, attributeFilter: ['disabled'] });

        return () => observer.disconnect();
    }, [screen]);
}
