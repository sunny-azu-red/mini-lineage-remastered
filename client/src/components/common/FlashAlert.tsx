import { useGameStore } from '@/store/gameStore';

export default function FlashAlert() {
    const flash = useGameStore(state => state.flash);
    if (!flash)
        return null;

    // Safe by construction (plan decision A12, "Narrative HTML"): flash.text is always composed
    // server-side from fixed narrative templates (see narratives.constant.ts / makeFlash) — no
    // player-controlled string (name, item names, etc.) is ever interpolated into it. Player
    // names and other user-supplied data are sent as separate plain fields and rendered as
    // normal React children elsewhere, never through this component. Do NOT "fix" this into
    // React children without re-verifying that invariant server-side.
    return <div className={`alert alert-${flash.type}`} dangerouslySetInnerHTML={{ __html: flash.text }} />;
}
