import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import { render, screen, fireEvent, act } from '@testing-library/react';
import type { GameCatalog, PlayerSnapshot } from '@shared/contract';
import { useGameStore } from '@/store/gameStore';
import { makeCatalog, makePlayer } from '../../factories';

// The defaults this file's assertions were written against.
const localPlayer = (o: Partial<Parameters<typeof makePlayer>[0]> = {}) =>
    makePlayer({ raceId: 0, experience: 250, level: 3, xpCurrent: 50, xpRequired: 300, xpPercent: 16, xpNeeded: 50, adena: 1500, weapon: { id: 1, name: 'Elven Needle', emoji: '🗡️', stat: 16, cost: 300, crit: 5 }, armor: { id: 1, name: 'Leather Armor', emoji: '🥋', stat: 10, cost: 200, regen: 2 }, stats: { attack: 23, defense: 12, crit: 10, regen: 4, ambushRisk: 12 }, counters: { totalBattles: 7, totalAmbushes: 2, consecutiveAmbushes: 0, totalEnemiesKilled: 5 }, ...o });

// The defaults this file's assertions were written against.
const localCatalog = (o: Partial<Parameters<typeof makeCatalog>[0]> = {}) =>
    makeCatalog({ nameMinLength: 2, nameMaxLength: 16, races: [ { id: 0, label: 'Human', plural: 'Humans', emoji: '🧑', slug: 'human', enemyRaceId: 1, startHealth: 100, startAdena: 50, ambushChance: 5, regen: 2, crit: 5, backstory: 'Humans are <em>adaptable</em>.', traits: 'Balanced stats across the board.', }, { id: 1, label: 'Orc', plural: 'Orcs', emoji: '👹', slug: 'orc', enemyRaceId: 0, startHealth: 120, startAdena: 30, ambushChance: 8, regen: 1, crit: 3, backstory: 'Orcs are brutal.', traits: 'Strong but reckless.', }, ], ...o });

const { requestMock } = vi.hoisted(() => ({ requestMock: vi.fn() }));
vi.mock('@/socket/client', () => ({ request: requestMock }));

const { default: CharacterScreen } = await import('@/components/screens/CharacterScreen');

function stubMatchMedia(matches: boolean) {
    Object.defineProperty(window, 'matchMedia', {
        writable: true,
        configurable: true,
        value: vi.fn().mockImplementation((query: string) => ({
            matches, media: query, onchange: null,
            addListener: vi.fn(), removeListener: vi.fn(),
            addEventListener: vi.fn(), removeEventListener: vi.fn(), dispatchEvent: vi.fn(),
        })),
    });
}

// RaceType enum (backend/interface/index.ts): Human = 0, Orc = 1, Elf = 2, DarkElf = 3.
// Human's id 0 is the exact value that used to trip the `!player.raceId` falsy-zero bug — using
// the real enum values here (rather than the old ad-hoc 1/2 scheme) is what lets the regression
// test below actually exercise that bug.
function resetStore(player: PlayerSnapshot, catalog: GameCatalog = localCatalog()) {
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
        requestMock.mockReset();
        // navigate() always calls .then() on this now (to apply the player:screen ack to its
        // own store) — a safe default so tests that don't care about the response don't crash.
        requestMock.mockResolvedValue({ ok: false, error: { code: 'INTERNAL', message: 'mock default' } });
        resetStore(localPlayer());
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

        resetStore(localPlayer({ isMaxLevel: true }));
        render(<CharacterScreen />);
        expect(screen.getByText(/standing unchallenged at the zenith of martial prowess/)).toBeInTheDocument();
        expect(screen.queryByText(/requiring another/)).not.toBeInTheDocument();
    });

    // Regression test for the falsy-zero bug: RaceType.Human = 0 is a legitimate raceId, but the
    // old guard used `!player.raceId`, which is truthy for 0 and incorrectly bailed out with
    // `return null` for every Human player. The guard must check `raceId === null` instead.
    it('renders its content (not null) for a Human player, whose raceId is the falsy value 0', () => {
        resetStore(localPlayer({ raceId: 0 }));
        const { container } = render(<CharacterScreen />);

        expect(container).not.toBeEmptyDOMElement();
        expect(screen.getByText(/Hero of Human Ancestry/)).toBeInTheDocument();
    });

    it('renders nothing if the player has not started / catalog is missing critical data', () => {
        resetStore(localPlayer({ weapon: null }));
        const { container } = render(<CharacterScreen />);
        expect(container).toBeEmptyDOMElement();
    });

    it('renders nothing if raceId is genuinely null (no race assigned)', () => {
        resetStore(localPlayer({ raceId: null }));
        const { container } = render(<CharacterScreen />);
        expect(container).toBeEmptyDOMElement();
    });

    it('renders nothing when there is no player at all (pre-hydrate)', () => {
        useGameStore.setState({ player: null }, false);
        const { container } = render(<CharacterScreen />);
        expect(container).toBeEmptyDOMElement();
    });

    it('omits the crit/regen clauses for gear carrying no such modifiers', () => {
        resetStore(localPlayer({
            weapon: { id: 0, name: 'Bare Hands', emoji: '✊', stat: 1, cost: 0 },
            armor: { id: 0, name: `Peasant's Tunic`, emoji: '🥋', stat: 2, cost: 0 },
        }));
        render(<CharacterScreen />);

        expect(screen.queryByText('+0% Critical Hit Chance')).not.toBeInTheDocument();
        expect(screen.queryByText('+0 HP Regeneration')).not.toBeInTheDocument();
        // The totals sentence further down still renders its own crit/regen spans.
        expect(document.getElementById('char-stat-crit')?.textContent).toBe('10');
    });

    it('renders nothing if the player\'s raceId matches no race in the catalog', () => {
        resetStore(localPlayer({ raceId: 99 }));
        const { container } = render(<CharacterScreen />);
        expect(container).toBeEmptyDOMElement();
    });

    it('renders nothing if the race resolves but its enemyRaceId matches no race in the catalog', () => {
        const catalog = localCatalog();
        resetStore(localPlayer({ raceId: 0 }), { ...catalog, races: [{ ...catalog.races[0], enemyRaceId: 99 }] });
        const { container } = render(<CharacterScreen />);
        expect(container).toBeEmptyDOMElement();
    });

    // level/experience/maxHealth/adena are all nullable on the snapshot — a partially-populated
    // one must render plain zeroes rather than "null"/"NaN" anywhere in the prose.
    it('renders zeroes for null level, experience, maxHealth and adena', () => {
        resetStore(localPlayer({ level: null, experience: null, maxHealth: null, adena: null }));
        render(<CharacterScreen />);

        expect(screen.getByText(/Level 0/)).toBeInTheDocument();
        // Anchored so this can't also match the "50 XP" (xpNeeded) span further along.
        expect(screen.getByText(/^0 XP$/)).toBeInTheDocument();
        expect(document.getElementById('char-max-hp')?.textContent).toBe('0');
        expect(screen.getByText(/🪙 0 Adena/)).toBeInTheDocument();
    });

    it('the back link returns to Home Town instead of following the anchor', () => {
        render(<CharacterScreen />);

        const link = screen.getByRole('link', { name: 'Continue your journey' });
        // fireEvent returns false once preventDefault() has been called on the dispatched event.
        expect(fireEvent.click(link)).toBe(false);
        expect(useGameStore.getState().screen).toBe('home');
    });

    describe('HP counter animation (regression — this used to snap instantly instead of animating, unlike the sidebar)', () => {
        beforeEach(() => {
            vi.useFakeTimers();
            stubMatchMedia(false);
        });

        afterEach(() => {
            vi.useRealTimers();
        });

        it('animates #char-hp toward a new value over time, the same as the sidebar HP bar', () => {
            const { rerender } = render(<CharacterScreen />);
            expect(document.getElementById('char-hp')?.textContent).toBe('80');

            act(() => {
                resetStore(localPlayer({ health: 100 }));
                rerender(<CharacterScreen />);
            });
            act(() => {
                vi.advanceTimersByTime(300);
            });

            const midValue = Number(document.getElementById('char-hp')?.textContent);
            expect(midValue).toBeGreaterThan(80);
            expect(midValue).toBeLessThan(100);

            act(() => {
                vi.advanceTimersByTime(400);
            });
            expect(document.getElementById('char-hp')?.textContent).toBe('100');
        });
    });
});
