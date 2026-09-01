import { useEffect } from 'react';
import type { ScreenId } from '@shared/contract';

// Links are excluded: Space scrolls a link rather than activating it. `.alert-dismiss` (NoticeAlert's
// `×`) sits before the screen's own content, so without this exclusion the first Space after any
// error would dismiss the banner instead of playing.
const CONTROLS = 'input, select, button:not(.alert-dismiss)';

// You arrive here by dying, plausibly with a Space press already travelling — auto-focusing the
// first button ("Write your Legacy!"/"Play Again?") could submit or restart before it's read.
const NO_AUTOFOCUS: ReadonlySet<ScreenId> = new Set(['death']);

// Puts keyboard focus on the panel's first control, so the game is playable without a mouse. The
// MutationObserver (not a dependency array — `pending` is local state no parent re-renders on)
// re-claims focus once `useAction` re-enables a button, which a disabled element always lost.
// NOTE: jsdom doesn't blur a disabled element, so tests must call `.blur()` to reproduce that.
export function usePanelFocus(screen: ScreenId): void {
    useEffect(() => {
        if (NO_AUTOFOCUS.has(screen))
            return;

        // Scoped through #main: the sidebar's panels are `.panel-body` too and precede it in the DOM.
        // Null when ErrorBoundary trips and renders <ErrorScreen> bare, replacing AppShell.
        const panel = document.querySelector('#main .panel-body');
        if (!panel)
            return;

        const claim = (force: boolean) => {
            // A screen change should pull focus in; an in-screen mutation must stay gentle, so it
            // doesn't yank focus off a select mid-tab or a name field mid-word.
            if (!force && document.activeElement !== document.body)
                return;

            // Resolved unconditionally, then declined if disabled — not `:not(:disabled)` in the
            // selector, so a mid-request Fight button doesn't hand focus to some other control.
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
