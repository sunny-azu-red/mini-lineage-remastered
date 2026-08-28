import type { ItemView } from '@shared/contract';
import { formatAdena, formatNumber } from '@shared/format';
import { useGameStore } from '@/store/gameStore';
import { useAction } from '@/socket/useAction';
import { playSound } from '@/audio/soundfx';
import DataTable, { type Column } from '@/components/common/DataTable';
import SelectActionForm from '@/components/common/SelectActionForm';

const COLUMNS: Column<ItemView>[] = [
    { key: 'name', header: 'Name', render: weapon => <>{weapon.emoji} {weapon.name}</> },
    {
        key: 'crit',
        header: 'C. Hit %',
        headerTitle: 'Critical Hit Chance',
        render: weapon =>
            (weapon.crit ?? 0) > 0
                ? <span className="crit">{weapon.crit}%</span>
                : <span className="muted">-</span>,
    },
    { key: 'stat', header: 'P. Attack', render: weapon => formatNumber(weapon.stat) },
    { key: 'cost', header: 'Adena', render: weapon => <span className="gold">🪙 {formatAdena(weapon.cost)}</span> },
];

// Ported from weapons-shop.ejs + shop.js's `setupShop('weapon-select', 'weapon-btn', '🪙 Purchase')`.
// `catalog.weapons[0]` is the starting item (Brawler's Fists) and is never purchasable — sliced
// off both the table and the select, exactly like today's `WEAPONS.slice(1)` in shop.view.ts.
export default function WeaponsShopScreen() {
    const catalog = useGameStore(state => state.catalog);
    const player = useGameStore(state => state.player);
    const applyMutation = useGameStore(state => state.applyMutation);
    const navigate = useGameStore(state => state.navigate);
    const { run, pending } = useAction('shop:purchase');

    if (!catalog)
        return null;

    const purchasable = catalog.weapons.slice(1);

    function handlePurchase(value: string) {
        if (!value) {
            navigate('home');
            return;
        }

        void run(
            { type: 'weapon', itemId: Number(value) },
            {
                onSuccess: data => {
                    applyMutation(data.player, data.flash);
                    playSound(data.flash?.sound);
                },
            },
        );
    }

    return (
        <>
            <p>
                You have arrived at the Weapons Shop.
                <br />
                The nice man greets you and lets you look through his swords.
            </p>
            <DataTable minWidth={400} columns={COLUMNS} rows={purchasable} rowKey={weapon => weapon.id} />
            <SelectActionForm
                // Remounts (resetting the internal `selected` state back to the placeholder)
                // after every successful purchase — see InnScreen.tsx for the full rationale.
                key={player?.revision}
                options={purchasable.map(weapon => {
                    const owned = player?.weapon?.id === weapon.id;
                    return {
                        value: String(weapon.id),
                        label: `Pick ${weapon.emoji} ${weapon.name}${owned ? ' (Owned)' : ''}`,
                        disabled: owned,
                    };
                })}
                placeholderLabel="🚪 Home Town"
                defaultButtonLabel="Return"
                activeButtonLabel="🪙 Purchase"
                pending={pending}
                onSubmit={handlePurchase}
            />
        </>
    );
}
