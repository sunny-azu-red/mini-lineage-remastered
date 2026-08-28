import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen } from '@testing-library/react';
import type { GameCatalog, PlayerSnapshot } from '@shared/contract';
import { useGameStore, type ScreenId } from '@/store/gameStore';

vi.mock('@/socket/client', () => ({ request: vi.fn() }));

const { default: AppShell } = await import('./AppShell');

function makeCatalog(): GameCatalog {
    return {
        version: '1.5.0',
        isRelease: false,
        commitUrl: null,
        year: 2026,
        locale: 'en-US',
        lowHealthThreshold: 0.2,
        maxLevel: 50,
        nameMinLength: 1,
        nameMaxLength: 20,
        races: [],
        weapons: [],
        armors: [],
        foods: [],
    };
}

function makePlayer(overrides: Partial<PlayerSnapshot> = {}): PlayerSnapshot {
    return {
        revision: 1,
        started: true,
        name: 'Hero',
        raceId: 1,
        raceLabel: 'Human',
        raceEmoji: '🧑',
        health: 80,
        maxHealth: 100,
        hpPercent: 80,
        lowHealth: false,
        experience: 10,
        level: 2,
        isMaxLevel: false,
        xpCurrent: 10,
        xpRequired: 100,
        xpPercent: 10,
        xpNeeded: 90,
        adena: 500,
        weapon: null,
        armor: null,
        stats: null,
        effects: [],
        dead: false,
        ambushed: false,
        coward: false,
        cheated: false,
        deathReason: null,
        highscoreEligible: false,
        counters: { totalBattles: 0, totalAmbushes: 0, consecutiveAmbushes: 0, totalEnemiesKilled: 0 },
        lastBattle: null,
        ...overrides,
    };
}

function setStore(screenId: ScreenId, player: PlayerSnapshot | null) {
    useGameStore.setState(
        {
            status: 'ready',
            player,
            catalog: makeCatalog(),
            screen: screenId,
            highscoreRaceFilter: null,
            flash: null,
            lastBattle: null,
            notice: null,
            soundEnabled: false,
        },
        false,
    );
}

describe('AppShell', () => {
    beforeEach(() => {
        vi.clearAllMocks();
    });

    it.each<ScreenId>(['home', 'battle', 'weapons', 'armors', 'inn', 'suicide', 'death'])(
        'shows the sidebar on screen "%s" once the player has started',
        screenId => {
            setStore(screenId, makePlayer());
            render(<AppShell><div /></AppShell>);
            expect(document.getElementById('sidebar')).not.toBeNull();
        },
    );

    it.each<ScreenId>(['start', 'character', 'highscores', 'statistics', 'races', 'error'])(
        'hides the sidebar on screen "%s" even once the player has started',
        screenId => {
            setStore(screenId, makePlayer());
            render(<AppShell><div /></AppShell>);
            expect(document.getElementById('sidebar')).toBeNull();
        },
    );

    it('hides the sidebar on the pre-game Game Start screen (player exists but has not started)', () => {
        setStore('start', makePlayer({ started: false }));
        render(<AppShell><div /></AppShell>);
        expect(document.getElementById('sidebar')).toBeNull();
    });

    it('hides the sidebar on an allowlisted screen when the player has not started (e.g. right after Death -> Play Again resets in place)', () => {
        setStore('home', makePlayer({ started: false }));
        render(<AppShell><div /></AppShell>);
        expect(document.getElementById('sidebar')).toBeNull();
    });

    it('hides the sidebar when there is no player at all', () => {
        setStore('home', null);
        render(<AppShell><div /></AppShell>);
        expect(document.getElementById('sidebar')).toBeNull();
    });

    it('renders the children passed to it', () => {
        setStore('home', makePlayer());
        render(<AppShell><div data-testid="child-content">hello</div></AppShell>);
        expect(screen.getByTestId('child-content')).toBeInTheDocument();
    });
});
