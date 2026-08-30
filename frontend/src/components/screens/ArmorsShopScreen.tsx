import { useGameStore } from '@/store/gameStore';
import ShopScreen from './ShopScreen';

// catalog.armors[0] is the starting item (Peasant's Tunic) and is never purchasable.
export default function ArmorsShopScreen() {
    const catalog = useGameStore(state => state.catalog);
    const player = useGameStore(state => state.player);

    if (!catalog)
        return null;

    return (
        <ShopScreen
            type="armor"
            items={catalog.armors.slice(1)}
            ownedItemId={player?.armor?.id}
            modifier={{ key: 'regen', header: 'HP Regen', headerTitle: 'Health Point Regeneration', className: 'heal', prefix: '+' }}
            statHeader="P. Defense"
            statHeaderTitle="Physical Defense"
            actionLabel="🪙 Purchase"
            intro={<>
                You have arrived at the Armor Shop.
                <br />
                The old man greets you and lets you look through his armors.
            </>}
        />
    );
}
