import type { ItemView } from '@shared/contract';
import { formatAdena, formatNumber } from '@shared/format';
import { useGameStore } from '@/store/gameStore';
import { useAction } from '@/socket/useAction';
import { playSound } from '@/audio/soundfx';
import DataTable, { type Column } from '@/components/common/DataTable';
import SelectActionForm from '@/components/common/SelectActionForm';

const COLUMNS: Column<ItemView>[] = [
    { key: 'name', header: 'Name', render: food => <>{food.emoji} {food.name}</> },
    {
        key: 'maxHealth',
        header: 'Max HP+',
        headerTitle: 'Maximum Health Point Increase',
        render: food =>
            (food.maxHealth ?? 0) > 0
                ? <span className="hp">+{food.maxHealth}</span>
                : <span className="muted">-</span>,
    },
    { key: 'stat', header: 'HP Heal', render: food => formatNumber(food.stat) },
    { key: 'cost', header: 'Adena', render: food => <span className="gold">🪙 {formatAdena(food.cost)}</span> },
];

// Ported from inn.ejs + shop.js's `setupShop('inn-select', 'inn-btn', '🪙 Order')`. Purchase
// stays on this screen after success (matching today's POST /inn redirecting back to /inn) — the
// flash renders via the already-mounted FlashAlert reading store.flash.
export default function InnScreen() {
    const catalog = useGameStore(state => state.catalog);
    const applyMutation = useGameStore(state => state.applyMutation);
    const { run, pending } = useAction('shop:purchase');

    if (!catalog)
        return null;

    function handlePurchase(value: string) {
        void run(
            { type: 'food', itemId: Number(value) },
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
                You have arrived at the Inn.
                <br />
                The young lady greets you and sets you at a table.
            </p>
            <DataTable minWidth={400} columns={COLUMNS} rows={catalog.foods} rowKey={food => food.id} />
            <SelectActionForm
                options={catalog.foods.map(food => ({ value: String(food.id), label: `Pick ${food.emoji} ${food.name}` }))}
                placeholderLabel="🚪 Home Town"
                defaultButtonLabel="Return"
                activeButtonLabel="🪙 Order"
                pending={pending}
                onSubmit={handlePurchase}
            />
        </>
    );
}
