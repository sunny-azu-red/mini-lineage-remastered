import { describe, it, expect, beforeEach } from 'vitest';
import { render, screen } from '@testing-library/react';
import type { GameCatalog, PlayerSnapshot } from '@shared/contract';
import { useGameStore } from '@/store/gameStore';
import RacesScreen from './RacesScreen';

function makeCatalog(): GameCatalog {
    return {
        version: '1.5.0', isRelease: false, commitUrl: null, year: 2026, locale: 'en-US',
        lowHealthThreshold: 0.2, maxLevel: 50, nameMinLength: 2, nameMaxLength: 16,
        races: [
            {
                id: 1, label: 'Human', plural: 'Humans', emoji: '🧑', slug: 'human',
                enemyRaceId: 2, startHealth: 100, startAdena: 50, ambushChance: 5, regen: 2, crit: 5,
                backstory: 'Humans are <em>adaptable</em>.', traits: 'Balanced <strong>stats</strong>.',
            },
            {
                id: 2, label: 'Orc', plural: 'Orcs', emoji: '👹', slug: 'orc',
                enemyRaceId: 1, startHealth: 120, startAdena: 30, ambushChance: 8, regen: 1, crit: 3,
                backstory: 'Orcs are brutal.', traits: 'Strong but reckless.',
            },
        ],
        weapons: [], armors: [], foods: [],
    };
}

function makePlayer(overrides: Partial<PlayerSnapshot> = {}): PlayerSnapshot {
    return {
        revision: 1, started: false, name: null, raceId: null, raceLabel: null, raceEmoji: null,
        health: null, maxHealth: null, hpPercent: 0, lowHealth: false,
        experience: null, level: null, isMaxLevel: false, xpCurrent: 0, xpRequired: 0, xpPercent: 0, xpNeeded: 0,
        adena: null, weapon: null, armor: null, stats: null, effects: [],
        dead: false, ambushed: false, coward: false, cheated: false, deathReason: null, highscoreEligible: false,
        counters: { totalBattles: 0, totalAmbushes: 0, consecutiveAmbushes: 0, totalEnemiesKilled: 0 },
        lastBattle: null,
        ...overrides,
    };
}

function resetStore(overrides: Partial<ReturnType<typeof useGameStore.getState>> = {}) {
    useGameStore.setState(
        {
            status: 'ready',
            player: makePlayer(),
            catalog: makeCatalog(),
            screen: 'races',
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

describe('RacesScreen', () => {
    beforeEach(() => resetStore());

    it('renders every catalog race with its backstory/traits HTML via Narrative', () => {
        render(<RacesScreen />);

        expect(screen.getByText(/🧑 Human/)).toBeInTheDocument();
        expect(screen.getByText('adaptable')).toBeInTheDocument(); // <em> content, proves raw HTML rendered
        expect(screen.getByText('stats').tagName).toBe('STRONG');

        expect(screen.getByText(/👹 Orc/)).toBeInTheDocument();
        expect(screen.getByText('Orcs are brutal.')).toBeInTheDocument();
        expect(screen.getByText('Strong but reckless.')).toBeInTheDocument();
    });

    it('links back to "start" when no character has been started yet', () => {
        render(<RacesScreen />);
        expect(screen.getByRole('link', { name: /Go back to game start/ })).toBeInTheDocument();
    });

    it('renders nothing while catalog has not loaded', () => {
        useGameStore.setState({ catalog: null }, false);
        const { container } = render(<RacesScreen />);
        expect(container).toBeEmptyDOMElement();
    });
});
