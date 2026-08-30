import { useGameStore } from '@/store/gameStore';

export default function FlashAlert() {
    const flash = useGameStore(state => state.flash);

    if (!flash)
        return null;

    // Same narrative-safety invariant as `Narrative`: flash.text is always composed server-side
    // from fixed templates, never from player-supplied strings. Do NOT convert this to React
    // children without re-verifying that server-side.
    return <div className={`alert alert-${flash.type}`} dangerouslySetInnerHTML={{ __html: flash.text }} />;
}
