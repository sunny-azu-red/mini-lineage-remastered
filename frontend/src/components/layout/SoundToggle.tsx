import { useGameStore } from '@/store/gameStore';
import { playSound } from '@/audio/soundfx';

// A chime confirms only when the click is ENABLING sound. Played here, not in toggleSound() itself,
// to avoid a circular import between the store and the audio module.
export default function SoundToggle() {
    const soundEnabled = useGameStore(state => state.soundEnabled);
    const toggleSound = useGameStore(state => state.toggleSound);

    const title = soundEnabled ? 'Sound FX Enabled (Click to Mute)' : 'Sound FX Muted (Click to Unmute)';

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
            className={`sound-toggle-btn${soundEnabled ? '' : ' muted'}`}
            title={title}
            aria-label={title}
            onClick={handleClick}
        >
            {soundEnabled ? '🔊' : '🔇'}
        </button>
    );
}
