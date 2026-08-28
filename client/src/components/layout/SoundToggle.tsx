import { useGameStore } from '@/store/gameStore';

/**
 * UI-only for now (no audio wiring yet — that lands in a later task). Mirrors
 * public/js/audio.js's updateToggleUI() exactly: emoji glyph, title/aria-label text, and the
 * `.muted` class toggle.
 */
export default function SoundToggle() {
    const soundEnabled = useGameStore(state => state.soundEnabled);
    const toggleSound = useGameStore(state => state.toggleSound);

    const title = soundEnabled
        ? 'Sound FX Enabled (Click to Mute)'
        : 'Sound FX Muted (Click to Unmute)';

    return (
        <button
            id="sound-toggle"
            type="button"
            className={`sound-toggle-btn no-debounce${soundEnabled ? '' : ' muted'}`}
            title={title}
            aria-label={title}
            onClick={toggleSound}
        >
            {soundEnabled ? '🔊' : '🔇'}
        </button>
    );
}
