import { useGameStore } from '@/store/gameStore';
import ShopScreen from './ShopScreen';

// catalog.weapons[0] is the starting item (Brawler's Fists) and is never purchasable.
export default function WeaponsShopScreen() {
    const catalog = useGameStore(state => state.catalog);
    const player = useGameStore(state => state.player);

    if (!catalog)
        return null;

    return (
        <ShopScreen
            type="weapon"
            items={catalog.weapons.slice(1)}
            ownedItemId={player?.weapon?.id}
            modifier={{ key: 'crit', header: 'C. Hit %', headerTitle: 'Critical Hit Chance', className: 'crit', suffix: '%' }}
            statHeader="P. Attack"
            statHeaderTitle="Physical Attack"
            actionLabel="🪙 Purchase"
            intro={<>
                You have arrived at the Weapons Shop.
                <br />
                The nice man greets you and lets you look through his swords.
            </>}
        />
    );
}
