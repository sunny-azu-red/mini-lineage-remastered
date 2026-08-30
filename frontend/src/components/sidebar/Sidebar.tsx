import StatusPanel from './StatusPanel';
import InventoryPanel from './InventoryPanel';

export default function Sidebar() {
    return (
        <div id="sidebar">
            <StatusPanel />
            <InventoryPanel />
        </div>
    );
}
