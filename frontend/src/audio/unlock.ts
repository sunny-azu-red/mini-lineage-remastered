import { getAudioContext } from './soundfx';

/**
 * Resumes the shared AudioContext on the very first user gesture anywhere on the page. Call ONCE
 * from main.tsx, before the React tree renders.
 *
 * This is what fixed audio breaking on refresh: the old script auto-played on DOMContentLoaded,
 * before any gesture, so `resume()` silently no-op'd. Nothing plays outside a click handler's
 * response now, and this listener runs at the very start of that same first click's dispatch — so
 * the context is always unlocked before any sound is asked to play.
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

    for (const event of ['pointerdown', 'keydown'] as const)
        window.addEventListener(event, unlock, { capture: true, once: true });
}
