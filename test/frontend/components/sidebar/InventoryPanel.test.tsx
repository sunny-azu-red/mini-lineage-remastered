import { describe, it, expect, beforeEach } from 'vitest';
import { render, screen } from '@testing-library/react';
import { useGameStore } from '@/store/gameStore';
import InventoryPanel from '@/components/sidebar/InventoryPanel';
import { makePlayer } from '../../factories';

// The defaults this file's assertions were written against.
const localPlayer = (o: Partial<Parameters<typeof makePlayer>[0]> = {}) =>
    makePlayer({ weapon: { id: 1, name: 'Elven Needle', emoji: '🗡️', stat: 16, cost: 300, crit: 5 }, armor: { id: 1, name: 'Leather Armor', emoji: '🥋', stat: 10, cost: 200, regen: 2 }, ...o });

function resetStore(overrides: Partial<ReturnType<typeof useGameStore.getState>> = {}) {
    useGameStore.setState(
        {
            status: 'ready',
            player: localPlayer(),
            catalog: null,
            screen: 'home',
            highscoreRaceFilter: null,
            flash: null,
            lastBattle: null,
            notice: null,
            soundEnabled: false,
            ...overrides,
        },
        false,
    );
}

describe('InventoryPanel', () => {
    beforeEach(() => resetStore());

    it('renders nothing at all when there is no player yet', () => {
        resetStore({ player: null });
        const { container } = render(<InventoryPanel />);

        expect(container).toBeEmptyDOMElement();
    });

    it('renders the equipped armor and weapon rows with their title tooltips', () => {
        render(<InventoryPanel />);

        expect(screen.getByTitle('Equipped Armor').textContent).toContain('🥋 Leather Armor');
        expect(screen.getByTitle('Equipped Weapon').textContent).toContain('🗡️ Elven Needle');
    });

    it('shows the regen and crit modifier spans when those modifiers are non-zero', () => {
        const { container } = render(<InventoryPanel />);

        expect(container.querySelector('.heal')?.textContent).toBe('+2');
        expect(container.querySelector('.crit')?.textContent).toBe('5%');
    });

    it('omits the modifier spans for gear whose regen/crit are zero', () => {
        resetStore({
            player: localPlayer({
                armor: { id: 0, name: `Peasant's Tunic`, emoji: '🥋', stat: 2, cost: 0, regen: 0 },
                weapon: { id: 0, name: 'Bare Hands', emoji: '✊', stat: 1, cost: 0, crit: 0 },
            }),
        });
        const { container } = render(<InventoryPanel />);

        expect(container.querySelector('.heal')).toBeNull();
        expect(container.querySelector('.crit')).toBeNull();
    });

    it('omits the modifier spans for gear that carries no regen/crit fields at all (the ?? 0 fallback)', () => {
        resetStore({
            player: localPlayer({
                armor: { id: 0, name: `Peasant's Tunic`, emoji: '🥋', stat: 2, cost: 0 },
                weapon: { id: 0, name: 'Bare Hands', emoji: '✊', stat: 1, cost: 0 },
            }),
        });
        const { container } = render(<InventoryPanel />);

        expect(container.querySelector('.heal')).toBeNull();
        expect(container.querySelector('.crit')).toBeNull();
    });

    // Defensive per the component's own doc comment — AppShell only mounts the sidebar once
    // `player.started`, but null gear must still degrade to an empty panel, not a crash.
    it('renders an empty panel body when neither armor nor weapon exists yet', () => {
        resetStore({ player: localPlayer({ armor: null, weapon: null }) });
        const { container } = render(<InventoryPanel />);

        expect(screen.getByText('Inventory')).toBeInTheDocument();
        expect(container.querySelectorAll('.stat-row')).toHaveLength(0);
    });

    it('renders only the weapon row when armor alone is missing', () => {
        resetStore({ player: localPlayer({ armor: null }) });
        const { container } = render(<InventoryPanel />);

        expect(container.querySelectorAll('.stat-row')).toHaveLength(1);
        expect(screen.getByTitle('Equipped Weapon')).toBeInTheDocument();
        expect(screen.queryByTitle('Equipped Armor')).not.toBeInTheDocument();
    });

    it('renders only the armor row when the weapon alone is missing', () => {
        resetStore({ player: localPlayer({ weapon: null }) });
        const { container } = render(<InventoryPanel />);

        expect(container.querySelectorAll('.stat-row')).toHaveLength(1);
        expect(screen.getByTitle('Equipped Armor')).toBeInTheDocument();
        expect(screen.queryByTitle('Equipped Weapon')).not.toBeInTheDocument();
    });
});
