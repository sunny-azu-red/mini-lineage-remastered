import { describe, it, expect, beforeEach } from 'vitest';
import type { GameCatalog, PlayerSnapshot, HydratePayload } from '@shared/contract';
import { useGameStore } from './gameStore';

function makeCatalog(): GameCatalog {
    return {
        version: '1.5.0',
        isRelease: false,
        year: 2026,
        locale: 'en-US',
        lowHealthThreshold: 0.2,
        maxLevel: 50,
        nameMinLength: 2,
        nameMaxLength: 16,
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
        effects: [
            { id: 'e1', type: 'buff', emoji: '💪', label: 'Strength', tooltip: 'Strength (+5 Attack)' },
        ],
        dead: false,
        ambushed: false,
        coward: false,
        cheated: false,
        deathReason: null,
        highscoreEligible: false,
        counters: { totalBattles: 0, totalAmbushes: 0, consecutiveAmbushes: 0, totalEnemiesKilled: 0 },
        ...overrides,
    };
}

function resetStore() {
    useGameStore.setState(
        {
            status: 'connecting',
            player: null,
            catalog: null,
            screen: 'start',
            highscoreRaceFilter: null,
            flash: null,
            lastBattle: null,
            notice: null,
            soundEnabled: true,
        },
        false,
    );
}

describe('gameStore', () => {
    beforeEach(() => {
        resetStore();
    });

    describe('hydrate — first hydrate this session', () => {
        it('picks the "start" screen when there is no player yet', () => {
            const payload: HydratePayload = { player: null, catalog: makeCatalog() };
            useGameStore.getState().hydrate(payload);
            expect(useGameStore.getState().screen).toBe('start');
        });

        it('picks the "start" screen for a never-started player even when the server sends a non-null snapshot', () => {
            // The real server (src/socket/index.ts) never actually sends a literal `null` —
            // a brand-new visitor's snapshot is `buildPlayerSnapshot({})`, i.e. a real object
            // with `started: false`. Regression guard for a real gap: `hydrate()` used to branch
            // on `p.player === null` instead of `.started`, which would have misrouted this
            // (extremely common — every first-time visitor) case to 'home'.
            const payload: HydratePayload = { player: makePlayer({ started: false, dead: false, name: null }), catalog: makeCatalog() };
            useGameStore.getState().hydrate(payload);
            expect(useGameStore.getState().screen).toBe('start');
        });

        it('picks the "home" screen for a live player', () => {
            const payload: HydratePayload = { player: makePlayer({ dead: false }), catalog: makeCatalog() };
            useGameStore.getState().hydrate(payload);
            expect(useGameStore.getState().screen).toBe('home');
        });

        it('picks the "death" screen for a dead player', () => {
            const payload: HydratePayload = { player: makePlayer({ dead: true }), catalog: makeCatalog() };
            useGameStore.getState().hydrate(payload);
            expect(useGameStore.getState().screen).toBe('death');
        });
    });

    describe('hydrate — reconnect (subsequent hydrate)', () => {
        it('preserves the current screen on an ordinary reconnect', () => {
            const catalog = makeCatalog();
            useGameStore.getState().hydrate({ player: makePlayer({ dead: false }), catalog });
            useGameStore.getState().navigate('battle');

            // Reconnect: player state unchanged (still alive, ambushed even) — screen must NOT
            // be clobbered back to 'home'. This is the core "refresh mid-ambush is harmless"
            // invariant.
            useGameStore.getState().hydrate({ player: makePlayer({ dead: false, ambushed: true }), catalog });

            expect(useGameStore.getState().screen).toBe('battle');
        });

        it('jumps to "death" when a reconnect reveals the player just died', () => {
            const catalog = makeCatalog();
            useGameStore.getState().hydrate({ player: makePlayer({ dead: false }), catalog });
            useGameStore.getState().navigate('battle');

            useGameStore.getState().hydrate({ player: makePlayer({ dead: true }), catalog });

            expect(useGameStore.getState().screen).toBe('death');
        });

        it('routes back to "start" when a reset (game:restart / highscore submit) lands', () => {
            const catalog = makeCatalog();
            useGameStore.getState().hydrate({ player: makePlayer({ dead: true }), catalog });
            expect(useGameStore.getState().screen).toBe('death');

            // The server never sends a literal `null` player (see hydrate()'s own comment) —
            // a reset player is a real PlayerSnapshot with `started: false` and every other
            // field back at its empty default (mirrors buildPlayerSnapshot's EMPTY_SNAPSHOT_DEFAULTS).
            const resetPlayer = makePlayer({ started: false, dead: false, name: null, raceId: null });
            useGameStore.getState().hydrate({ player: resetPlayer, catalog });

            expect(useGameStore.getState().screen).toBe('start');
        });

        it('does not re-jump to death on every subsequent reconnect once already on the death screen', () => {
            const catalog = makeCatalog();
            useGameStore.getState().hydrate({ player: makePlayer({ dead: true }), catalog });
            expect(useGameStore.getState().screen).toBe('death');

            useGameStore.getState().navigate('highscores');
            // A further reconnect where dead was ALREADY true before this hydrate (not a fresh
            // transition) must not force the screen back to death.
            useGameStore.getState().hydrate({ player: makePlayer({ dead: true }), catalog });

            expect(useGameStore.getState().screen).toBe('highscores');
        });
    });

    describe('applyUpdate', () => {
        it('shallow-merges without dropping unrelated fields', () => {
            const catalog = makeCatalog();
            useGameStore.getState().hydrate({ player: makePlayer({ health: 50, effects: [
                { id: 'e1', type: 'buff', emoji: '💪', label: 'Strength', tooltip: 'x' },
            ] }), catalog });

            useGameStore.getState().applyUpdate({ health: 5 });

            const player = useGameStore.getState().player;
            expect(player?.health).toBe(5);
            expect(player?.effects).toHaveLength(1);
            expect(player?.effects[0].id).toBe('e1');
            expect(player?.name).toBe('Hero');
        });

        it('is a no-op when player is currently null', () => {
            useGameStore.getState().applyUpdate({ health: 5 });
            expect(useGameStore.getState().player).toBeNull();
        });
    });

    describe('applyMutation', () => {
        it('replaces player wholesale and sets flash, clearing any stale notice', () => {
            useGameStore.getState().setNotice({ code: 'RATE_LIMITED', message: 'slow down' });
            const newPlayer = makePlayer({ adena: 999 });

            useGameStore.getState().applyMutation(newPlayer, { text: 'Bought!', type: 'success' });

            const state = useGameStore.getState();
            expect(state.player).toBe(newPlayer);
            expect(state.flash).toEqual({ text: 'Bought!', type: 'success' });
            expect(state.notice).toBeNull();
        });
    });

    describe('recordBattleResult', () => {
        it('replaces player, sets flash/lastBattle, and clears any stale notice', () => {
            useGameStore.getState().setNotice({ code: 'RATE_LIMITED', message: 'slow down' });
            const player = makePlayer({ health: 42 });
            const result = {
                player,
                outcome: {
                    enemiesKilled: 1, hpLost: 5, damageBlocked: 2, xpGained: 10, adenaGained: 3,
                    isCritical: true, isLevelUp: false,
                },
                narrative: {
                    critLine: 'crit!', killLine: 'kill', deflectionLine: 'deflect',
                    outcomeLine: 'outcome', ambushLine: null, fightPrompt: null, nextMove: 'Strike',
                },
                ambushed: false,
                died: false,
                flash: null,
                sound: 'crit' as const,
            };

            useGameStore.getState().recordBattleResult(result);

            const state = useGameStore.getState();
            expect(state.player).toBe(player);
            expect(state.lastBattle).toBe(result);
            expect(state.flash).toBeNull();
            expect(state.notice).toBeNull();
        });
    });

    describe('toggleSound', () => {
        it('flips soundEnabled', () => {
            const before = useGameStore.getState().soundEnabled;
            useGameStore.getState().toggleSound();
            expect(useGameStore.getState().soundEnabled).toBe(!before);
        });
    });
});
