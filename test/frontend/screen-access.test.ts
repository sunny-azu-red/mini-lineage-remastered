import { describe, it, expect, vi, beforeEach } from 'vitest';
import { renderHook } from '@testing-library/react';
import type { ScreenId } from '@shared/contract';

const { requestMock } = vi.hoisted(() => ({ requestMock: vi.fn() }));
vi.mock('@/socket/client', () => ({ request: requestMock }));

const { useGameStore } = await import('@/store/gameStore');
const { useHistorySync } = await import('@/hooks/useHistorySync');
const { makePlayer, makeCatalog } = await import('./factories');

/**
 * Acceptance suite for the screen-access policy — a direct port of the old app's global
 * `cheatMiddleware`, which redirected on every request. It is stated once here, end to end,
 * because the rules are only meaningful together: each one is reachable by an in-app link, a
 * typed URL AND the Back button, and all three must agree.
 *
 * The rules, from `main`'s src/middleware/cheat.middleware.ts:
 *   - a dead player is confined to the death screen
 *   - a living player may not visit the death screen (it offers "Play Again?", which wipes them)
 *   - a player with a character may not visit character creation, Statistics or Races
 *   - a visitor with no character may only visit Game Start, Statistics, Races and Highscores
 *   - an ambushed player is confined to the battleground
 */

const ALIVE = { started: true, dead: false, ambushed: false } as const;
const UNSTARTED = { started: false, name: null } as const;
const DEAD = { started: true, dead: true } as const;
const AMBUSHED = { started: true, dead: false, ambushed: true } as const;

type PlayerState = typeof ALIVE | typeof UNSTARTED | typeof DEAD | typeof AMBUSHED;

beforeEach(() => {
    requestMock.mockResolvedValue({ ok: false, error: { code: 'INTERNAL', message: 'mock' } });
    window.history.replaceState(null, '', '/');
    useGameStore.setState({ player: null, catalog: null, screen: 'start', highscoreRaceFilter: null }, false);
});

/** Where an in-app link lands. */
function viaLink(state: PlayerState, target: ScreenId): ScreenId {
    useGameStore.setState({ player: makePlayer(state), catalog: makeCatalog() }, false);
    useGameStore.getState().navigate(target);

    return useGameStore.getState().screen;
}

/** Where the Back button lands, given a history entry encoding `target`. */
function viaBackButton(state: PlayerState, target: ScreenId): ScreenId {
    useGameStore.setState({ player: makePlayer(state), catalog: makeCatalog() }, false);
    renderHook(() => useHistorySync());
    window.dispatchEvent(new PopStateEvent('popstate', { state: { screen: target, raceFilter: null } }));

    return useGameStore.getState().screen;
}

/** Where a typed URL lands, for a history entry this app never wrote. */
function viaTypedUrl(state: PlayerState, path: string): ScreenId {
    useGameStore.setState({ player: makePlayer(state), catalog: makeCatalog() }, false);
    renderHook(() => useHistorySync());
    window.history.pushState(null, '', path);
    window.dispatchEvent(new PopStateEvent('popstate', { state: null }));

    return useGameStore.getState().screen;
}

describe('screen access policy', () => {
    describe('a living character', () => {
        it.each(['statistics', 'races', 'start'] as const)(
            'cannot reach %s — those belong to character creation',
            (blocked) => {
                expect(viaLink(ALIVE, blocked)).toBe('home');
                expect(viaBackButton(ALIVE, blocked)).toBe('home');
            },
        );

        // The serious one: the death screen offers "Play Again?", which resets the character.
        it('cannot reach the death screen', () => {
            expect(viaLink(ALIVE, 'death')).toBe('home');
            expect(viaBackButton(ALIVE, 'death')).toBe('home');
            expect(viaTypedUrl(ALIVE, '/death')).toBe('home');
        });

        it.each(['home', 'inn', 'weapons', 'armors', 'battle', 'suicide', 'character', 'highscores'] as const)(
            'can still reach %s',
            (allowed) => {
                expect(viaLink(ALIVE, allowed)).toBe(allowed);
            },
        );
    });

    describe('a visitor with no character', () => {
        it.each(['battle', 'inn', 'weapons', 'armors', 'suicide', 'character', 'death'] as const)(
            'cannot reach %s',
            (blocked) => {
                expect(viaLink(UNSTARTED, blocked)).toBe('start');
                expect(viaBackButton(UNSTARTED, blocked)).toBe('start');
            },
        );

        it.each(['start', 'statistics', 'races', 'highscores'] as const)('can reach %s', (allowed) => {
            expect(viaLink(UNSTARTED, allowed)).toBe(allowed);
            expect(viaBackButton(UNSTARTED, allowed)).toBe(allowed);
        });

        it('is treated as unstarted when there is no player object at all', () => {
            useGameStore.setState({ player: null, catalog: makeCatalog() }, false);
            useGameStore.getState().navigate('battle');

            expect(useGameStore.getState().screen).toBe('start');
        });
    });

    describe('a dead character', () => {
        it.each(['home', 'inn', 'battle', 'highscores', 'statistics'] as const)(
            'is pinned to the death screen when trying to reach %s',
            (target) => {
                expect(viaLink(DEAD, target)).toBe('death');
                expect(viaBackButton(DEAD, target)).toBe('death');
            },
        );

        it('can be on the death screen', () => {
            expect(viaLink(DEAD, 'death')).toBe('death');
        });
    });

    describe('an ambushed character', () => {
        it.each(['home', 'inn', 'weapons', 'suicide', 'highscores', 'character'] as const)(
            'is pinned to the battleground when trying to reach %s',
            (target) => {
                expect(viaLink(AMBUSHED, target)).toBe('battle');
                expect(viaBackButton(AMBUSHED, target)).toBe('battle');
                expect(viaTypedUrl(AMBUSHED, '/inn')).toBe('battle');
            },
        );

        // killPlayer does not clear `ambushed`, so a corpse can still carry the flag. Death must
        // win: BattleScreen renders nothing for a corpse, so pinning there is a blank page with
        // no way off it.
        it('yields to death when the character is both dead and ambushed', () => {
            expect(viaLink({ started: true, dead: true, ambushed: true } as PlayerState, 'home')).toBe('death');
        });
    });
});
