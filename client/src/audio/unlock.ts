import { getAudioContext } from './soundfx';

/**
 * Installs one capture-phase, `{ once: true }` listener each for `pointerdown` and `keydown` on
 * `window`, resuming the shared `AudioContext` on the very first user gesture anywhere on the
 * page. Call this ONCE from main.tsx, before the React tree renders.
 *
 * This is the fix for hack #1 (`public/js/audio.js` auto-playing a `data-sound` element on
 * `DOMContentLoaded`, before any gesture had occurred, so `resume()` silently no-op'd on every
 * reload): in the new architecture nothing ever plays a sound outside of a click handler's
 * response (see the plan's Audio table), and this unlock listener runs at the very start of the
 * dispatch of that same first click/keydown — so the context is guaranteed unlocked before any
 * sound is ever asked to play. There is no load-time autoplay racing a gesture anymore.
 */
export function installAudioUnlock(): void {
    const unlock = () => {
        try {
            const ctx = getAudioContext();
            if (ctx.state === 'suspended')
                void ctx.resume();
        } catch {
            // Web Audio unavailable in this browser — nothing to unlock.
        }
    };

    window.addEventListener('pointerdown', unlock, { capture: true, once: true });
    window.addEventListener('keydown', unlock, { capture: true, once: true });
}
