import { getAudioContext } from './soundfx';

/**
 * Resumes the shared AudioContext on the very first user gesture anywhere on the page. Call ONCE
 * from main.tsx, before the React tree renders, so the context is always unlocked before anything
 * asks to play a sound.
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
