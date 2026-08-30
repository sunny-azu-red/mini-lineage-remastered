import { useGameStore } from '@/store/gameStore';
import ShopScreen from './ShopScreen';

// Buying stays on this screen; the flash renders via the already-mounted FlashAlert.
export default function InnScreen() {
    const catalog = useGameStore(state => state.catalog);

    if (!catalog)
        return null;

    return (
        <ShopScreen
            type="food"
            items={catalog.foods}
            modifier={{ key: 'maxHealth', header: 'Max HP+', headerTitle: 'Maximum Health Point Increase', className: 'hp', prefix: '+' }}
            statHeader="HP Heal"
            statHeaderTitle="Health Point Heal"
            actionLabel="🪙 Order"
            intro={<>
                You have arrived at the Inn.
                <br />
                The young lady greets you and sets you at a table.
            </>}
        />
    );
}
