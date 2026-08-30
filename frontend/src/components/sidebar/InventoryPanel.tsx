import type { ReactNode } from 'react';
import { useGameStore } from '@/store/gameStore';

export default function InventoryPanel() {
    const player = useGameStore(state => state.player);

    if (!player)
        return null;

    const { armor, weapon } = player;

    // The null checks are defensive — AppShell only mounts the sidebar once `player.started`.
    const row = (item: typeof armor, title: string, badge: ReactNode) => item && (
        <div className="stat-row">
            <span className="stat-value" title={title}>{item.emoji} {item.name}{badge}</span>
        </div>
    );

    return (
        <div className="panel inventory-panel">
            <div className="panel-header">Inventory</div>
            <div className="panel-body small">
                {row(armor, 'Equipped Armor', (armor?.regen ?? 0) > 0 && <span className="heal">+{armor!.regen}</span>)}
                {row(weapon, 'Equipped Weapon', (weapon?.crit ?? 0) > 0 && <span className="crit">{weapon!.crit}%</span>)}
            </div>
        </div>
    );
}
