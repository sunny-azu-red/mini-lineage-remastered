import { useGameStore } from '@/store/gameStore';

// Ported from partials/inventory.ejs. `weapon`/`armor` are `null` before a character exists
// (Sidebar is currently shown whenever `player !== null`, ahead of the `player.started` gate a
// later task adds) — each row simply doesn't render in that case.
export default function InventoryPanel() {
    const player = useGameStore(state => state.player);
    if (!player)
        return null;

    return (
        <div className="panel inventory-panel">
            <div className="panel-header">Inventory</div>
            <div className="panel-body small">
                {player.armor && (
                    <div className="stat-row">
                        <span className="stat-value" title="Equipped Armor">
                            {player.armor.emoji} {player.armor.name}
                            {(player.armor.regen ?? 0) > 0 && (
                                <span className="heal">+{player.armor.regen}</span>
                            )}
                        </span>
                    </div>
                )}
                {player.weapon && (
                    <div className="stat-row">
                        <span className="stat-value" title="Equipped Weapon">
                            {player.weapon.emoji} {player.weapon.name}
                            {(player.weapon.crit ?? 0) > 0 && (
                                <span className="crit">{player.weapon.crit}%</span>
                            )}
                        </span>
                    </div>
                )}
            </div>
        </div>
    );
}
