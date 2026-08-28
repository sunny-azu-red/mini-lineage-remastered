import type { ItemView } from '@shared/contract';
import { formatAdena, formatNumber } from '@shared/format';
import { useGameStore } from '@/store/gameStore';
import { useAction } from '@/socket/useAction';
import { playSound } from '@/audio/soundfx';
import DataTable, { type Column } from '@/components/common/DataTable';
import SelectActionForm from '@/components/common/SelectActionForm';

const COLUMNS: Column<ItemView>[] = [
    { key: 'name', header: 'Name', render: armor => <>{armor.emoji} {armor.name}</> },
    {
        key: 'regen',
        header: 'HP Regen',
        headerTitle: 'Health Point Regeneration',
        render: armor =>
            (armor.regen ?? 0) > 0
                ? <span className="heal">+{armor.regen}</span>
                : <span className="muted">-</span>,
    },
    { key: 'stat', header: 'P. Defense', headerTitle: 'Physical Defense', render: armor => formatNumber(armor.stat) },
    { key: 'cost', header: 'Adena', className: 'gold', render: armor => <>🪙 {formatAdena(armor.cost)}</> },
];

// Ported from armors-shop.ejs + shop.js's `setupShop('armor-select', 'armor-btn', '🪙 Purchase')`.
// `catalog.armors[0]` is the starting item (Peasant's Tunic) and is never purchasable — sliced
// off both the table and the select, exactly like today's `ARMORS.slice(1)` in shop.view.ts.
export default function ArmorsShopScreen() {
    const catalog = useGameStore(state => state.catalog);
    const player = useGameStore(state => state.player);
    const applyMutation = useGameStore(state => state.applyMutation);
    const navigate = useGameStore(state => state.navigate);
    const { run, pending } = useAction('shop:purchase');

    if (!catalog)
        return null;

    const purchasable = catalog.armors.slice(1);

    function handlePurchase(value: string) {
        if (!value) {
            navigate('home');
            return;
        }

        void run(
            { type: 'armor', itemId: Number(value) },
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
                You have arrived at the Armor Shop.
                <br />
                The old man greets you and lets you look through his armors.
            </p>
            <DataTable minWidth={400} columns={COLUMNS} rows={purchasable} rowKey={armor => armor.id} />
            <SelectActionForm
                // Remounts (resetting the internal `selected` state back to the placeholder)
                // after every successful purchase — see InnScreen.tsx for the full rationale.
                key={player?.revision}
                options={purchasable.map(armor => {
                    const owned = player?.armor?.id === armor.id;
                    return {
                        value: String(armor.id),
                        label: `Pick ${armor.emoji} ${armor.name}${owned ? ' (Owned)' : ''}`,
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
