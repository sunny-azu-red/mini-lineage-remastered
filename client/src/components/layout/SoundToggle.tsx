import { useGameStore } from '@/store/gameStore';
import { playSound } from '@/audio/soundfx';

/**
 * Mirrors public/js/audio.js's updateToggleUI() exactly: emoji glyph, title/aria-label text, and
 * the `.muted` class toggle. Also mirrors old `SoundFX.toggle()`'s `if (isSoundEnabled)
 * this.buy();` — a chime plays as audible confirmation only when this click is ENABLING sound
 * (never on mute, since there'd be nothing to hear or it'd play through a context about to go
 * silent). Read at the component level (rather than inside `gameStore.ts`'s `toggleSound()`) to
 * avoid a circular import between the store and the audio module.
 */
export default function SoundToggle() {
    const soundEnabled = useGameStore(state => state.soundEnabled);
    const toggleSound = useGameStore(state => state.toggleSound);

    const title = soundEnabled
        ? 'Sound FX Enabled (Click to Mute)'
        : 'Sound FX Muted (Click to Unmute)';

    function handleClick() {
        const willEnable = !soundEnabled;
        toggleSound();
        if (willEnable)
            playSound('buy');
    }

    return (
        <button
            id="sound-toggle"
            type="button"
            className={`sound-toggle-btn no-debounce${soundEnabled ? '' : ' muted'}`}
            title={title}
            aria-label={title}
            onClick={handleClick}
        >
            {soundEnabled ? '🔊' : '🔇'}
        </button>
    );
}
