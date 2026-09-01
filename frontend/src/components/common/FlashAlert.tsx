import { useGameStore } from '@/store/gameStore';

export default function FlashAlert() {
    const flash = useGameStore(state => state.flash);

    if (!flash)
        return null;

    // Same narrative-safety invariant as `Narrative`: flash.text is always server-composed, never
    // from player-supplied strings.
    return <div className={`alert alert-${flash.type}`} dangerouslySetInnerHTML={{ __html: flash.text }} />;
}
