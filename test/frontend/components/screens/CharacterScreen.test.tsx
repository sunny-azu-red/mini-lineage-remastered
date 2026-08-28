import { describe, it, expect, beforeEach } from 'vitest';
import { render, screen } from '@testing-library/react';
import type { GameCatalog, PlayerSnapshot } from '@shared/contract';
import { useGameStore } from '@/store/gameStore';
import CharacterScreen from '@/components/screens/CharacterScreen';

// RaceType enum (backend/interface/game.interface.ts): Human = 0, Orc = 1, Elf = 2, DarkElf = 3.
// Human's id 0 is the exact value that used to trip the `!player.raceId` falsy-zero bug — using
// the real enum values here (rather than the old ad-hoc 1/2 scheme) is what lets the regression
// test below actually exercise that bug.
function makeCatalog(): GameCatalog {
    return {
        version: '1.5.0', isRelease: false, commitUrl: null, year: 2026, locale: 'en-US',
        lowHealthThreshold: 0.2, maxLevel: 50, nameMinLength: 2, nameMaxLength: 16,
        races: [
            {
                id: 0, label: 'Human', plural: 'Humans', emoji: '🧑', slug: 'human',
                enemyRaceId: 1, startHealth: 100, startAdena: 50, ambushChance: 5, regen: 2, crit: 5,
                backstory: 'Humans are <em>adaptable</em>.', traits: 'Balanced stats across the board.',
            },
            {
                id: 1, label: 'Orc', plural: 'Orcs', emoji: '👹', slug: 'orc',
                enemyRaceId: 0, startHealth: 120, startAdena: 30, ambushChance: 8, regen: 1, crit: 3,
                backstory: 'Orcs are brutal.', traits: 'Strong but reckless.',
            },
        ],
        weapons: [], armors: [], foods: [],
    };
}

function makePlayer(overrides: Partial<PlayerSnapshot> = {}): PlayerSnapshot {
    return {
        revision: 1,
        started: true,
        name: 'Hero',
        raceId: 0,
        raceLabel: 'Human',
        raceEmoji: '🧑',
        health: 80,
        maxHealth: 100,
        hpPercent: 80,
        lowHealth: false,
        experience: 250,
        level: 3,
        isMaxLevel: false,
        xpCurrent: 50,
        xpRequired: 300,
        xpPercent: 16,
        xpNeeded: 50,
        adena: 1500,
        weapon: { id: 1, name: 'Elven Needle', emoji: '🗡️', stat: 16, cost: 300, crit: 5 },
        armor: { id: 1, name: 'Leather Armor', emoji: '🥋', stat: 10, cost: 200, regen: 2 },
        stats: { attack: 23, defense: 12, crit: 10, regen: 4, ambushRisk: 12 },
        effects: [],
        dead: false,
        ambushed: false,
        coward: false,
        cheated: false,
        deathReason: null,
        highscoreEligible: false,
        counters: { totalBattles: 7, totalAmbushes: 2, consecutiveAmbushes: 0, totalEnemiesKilled: 5 },
        lastBattle: null,
        ...overrides,
    };
}

function resetStore(player: PlayerSnapshot, catalog: GameCatalog = makeCatalog()) {
    useGameStore.setState(
        {
            status: 'ready',
            player,
            catalog,
            screen: 'character',
            highscoreRaceFilter: null,
            flash: null,
            lastBattle: null,
            notice: null,
            soundEnabled: false,
        },
        false,
    );
}

describe('CharacterScreen', () => {
    beforeEach(() => {
        resetStore(makePlayer());
    });

    it('renders the race header, backstory/traits HTML, and inventory stats from player+catalog', () => {
        render(<CharacterScreen />);

        expect(screen.getByText(/Hero of Human Ancestry/)).toBeInTheDocument();
        expect(screen.getByText('adaptable')).toBeInTheDocument(); // via Narrative's dangerouslySetInnerHTML
        expect(screen.getByText('Balanced stats across the board.')).toBeInTheDocument();

        expect(screen.getByText(/Elven Needle/)).toBeInTheDocument();
        expect(document.getElementById('char-stat-attack')?.textContent).toBe('23');
        expect(document.getElementById('char-stat-defense')?.textContent).toBe('12');
        expect(screen.getByText('+5% Critical Hit Chance')).toBeInTheDocument();
        expect(screen.getByText('+2 HP Regeneration')).toBeInTheDocument();
        expect(document.getElementById('char-stat-crit')?.textContent).toBe('10');
        expect(document.getElementById('char-stat-regen')?.textContent).toBe('4');
        expect(document.getElementById('char-stat-ambush')?.textContent).toBe('12');
    });

    it('pluralizes battles/ambushes and the opponent race group using the enemy race looked up via catalog', () => {
        render(<CharacterScreen />);

        // 7 battles, 2 ambushes, 5 enemies killed (of the Human's enemy race, Orc).
        expect(screen.getByText('7 battles')).toBeInTheDocument();
        expect(screen.getByText('2 cunning ambushes')).toBeInTheDocument();
        expect(screen.getByText(/5 👹 Orcs/)).toBeInTheDocument();
    });

    it('shows the "requires more XP" branch when not max level, and the zenith line when max level', () => {
        const { unmount } = render(<CharacterScreen />);
        expect(screen.getByText(/requiring another/)).toBeInTheDocument();
        // \b guards against also matching the "250 XP" (total experience) span above.
        expect(screen.getByText(/\b50 XP\b/)).toBeInTheDocument();
        expect(screen.getByText(/Level 4/)).toBeInTheDocument();
        unmount();

        resetStore(makePlayer({ isMaxLevel: true }));
        render(<CharacterScreen />);
        expect(screen.getByText(/standing unchallenged at the zenith of martial prowess/)).toBeInTheDocument();
        expect(screen.queryByText(/requiring another/)).not.toBeInTheDocument();
    });

    // Regression test for the falsy-zero bug: RaceType.Human = 0 is a legitimate raceId, but the
    // old guard used `!player.raceId`, which is truthy for 0 and incorrectly bailed out with
    // `return null` for every Human player. The guard must check `raceId === null` instead.
    it('renders its content (not null) for a Human player, whose raceId is the falsy value 0', () => {
        resetStore(makePlayer({ raceId: 0 }));
        const { container } = render(<CharacterScreen />);

        expect(container).not.toBeEmptyDOMElement();
        expect(screen.getByText(/Hero of Human Ancestry/)).toBeInTheDocument();
    });

    it('renders nothing if the player has not started / catalog is missing critical data', () => {
        resetStore(makePlayer({ weapon: null }));
        const { container } = render(<CharacterScreen />);
        expect(container).toBeEmptyDOMElement();
    });

    it('renders nothing if raceId is genuinely null (no race assigned)', () => {
        resetStore(makePlayer({ raceId: null }));
        const { container } = render(<CharacterScreen />);
        expect(container).toBeEmptyDOMElement();
    });
});
