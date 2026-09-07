import { useGameStore } from '@/store/gameStore';
import { narrativeHtml } from '@/components/common/narrative';

export default function FlashAlert() {
    const flash = useGameStore(state => state.flash);

    if (!flash)
        return null;

    return <div className={`alert alert-${flash.type}`} {...narrativeHtml(flash.text)} />;
}
