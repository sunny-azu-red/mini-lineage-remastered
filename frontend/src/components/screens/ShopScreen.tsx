import { useState, type ReactNode } from 'react';
import type { ItemView } from '@shared/contract';
import { formatAdena, formatNumber } from '@shared/format';
import { useGameStore } from '@/store/gameStore';
import { useAction } from '@/socket/useAction';
import { playSound } from '@/audio/soundfx';
import DataTable, { type Column } from '@/components/common/DataTable';
import SelectActionForm from '@/components/common/SelectActionForm';

/** The one column that differs between the three shops (regen / crit / max-HP). */
export interface ModifierColumn {
    key: 'regen' | 'crit' | 'maxHealth';
    header: string;
    headerTitle: string;
    /** Colour utility class applied when the value is > 0. */
    className: string;
    prefix?: string;
    suffix?: string;
}

export interface ShopScreenProps {
    type: 'weapon' | 'armor' | 'food';
    intro: ReactNode;
    items: ItemView[];
    modifier: ModifierColumn;
    statHeader: string;
    statHeaderTitle: string;
    actionLabel: string;
    /** The currently equipped item, marked "(Owned)" and disabled. Omitted by the Inn. */
    ownedItemId?: number | null;
}

// The shared Weapons Shop / Armor Shop / Inn screen — same table + select + button, different columns/copy.
export default function ShopScreen({
    type, intro, items, modifier, statHeader, statHeaderTitle, actionLabel, ownedItemId,
}: ShopScreenProps) {
    const applyMutation = useGameStore(state => state.applyMutation);
    const navigate = useGameStore(state => state.navigate);
    const { run, pending } = useAction('shop:purchase');
    // A LOCAL counter, deliberately not player.revision — that bumps on every session mutation
    // (a regen tick, another tab's purchase), which would remount the form and discard the selection.
    const [purchaseEpoch, setPurchaseEpoch] = useState(0);

    const columns: Column<ItemView>[] = [
        { key: 'name', header: 'Name', render: item => <>{item.emoji} {item.name}</> },
        {
            key: modifier.key,
            header: modifier.header,
            headerTitle: modifier.headerTitle,
            render: item => (item[modifier.key] ?? 0) > 0
                ? <span className={modifier.className}>{modifier.prefix ?? ''}{item[modifier.key]}{modifier.suffix ?? ''}</span>
                : <span className="muted">-</span>,
        },
        { key: 'stat', header: statHeader, headerTitle: statHeaderTitle, render: item => formatNumber(item.stat) },
        { key: 'cost', header: 'Adena', className: 'gold', render: item => <>🪙 {formatAdena(item.cost)}</> },
    ];

    function handlePurchase(value: string) {
        if (!value) {
            navigate('home');
            return;
        }

        void run({ type, itemId: Number(value) } as Parameters<typeof run>[0], {
            onSuccess: data => {
                applyMutation(data.player, data.flash);
                playSound(data.flash?.sound);
                setPurchaseEpoch(epoch => epoch + 1);
            },
        });
    }

    return (
        <>
            <p>{intro}</p>
            <DataTable minWidth={400} columns={columns} rows={items} rowKey={item => item.id} />
            <SelectActionForm
                key={purchaseEpoch} // remounting resets the select back to the placeholder after a purchase
                options={items.map(item => {
                    const owned = ownedItemId === item.id;
                    return {
                        value: String(item.id),
                        label: `Pick ${item.emoji} ${item.name}${owned ? ' (Owned)' : ''}`,
                        disabled: owned,
                    };
                })}
                placeholderLabel="🚪 Home Town"
                defaultButtonLabel="Return"
                activeButtonLabel={actionLabel}
                pending={pending}
                onSubmit={handlePurchase}
            />
        </>
    );
}
