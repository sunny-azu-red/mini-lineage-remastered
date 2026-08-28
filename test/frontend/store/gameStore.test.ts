import { describe, it, expect, beforeEach, vi } from 'vitest';
import type { GameCatalog, PlayerSnapshot, HydratePayload } from '@shared/contract';

const { requestMock } = vi.hoisted(() => ({ requestMock: vi.fn() }));

vi.mock('@/socket/client', () => ({
    request: requestMock,
}));

const { useGameStore } = await import('@/store/gameStore');

function makeCatalog(): GameCatalog {
    return {
        version: '1.5.0',
        isRelease: false,
        commitUrl: null,
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
        lastBattle: null,
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
        requestMock.mockReset();
        requestMock.mockResolvedValue({ ok: true, data: { player: makePlayer(), flash: null } });
        resetStore();
    });

    describe('hydrate — first hydrate this session', () => {
        it('picks the "start" screen when there is no player yet', () => {
            const payload: HydratePayload = { player: null, catalog: makeCatalog() };
            useGameStore.getState().hydrate(payload);
            expect(useGameStore.getState().screen).toBe('start');
        });

        it('picks the "start" screen for a never-started player even when the server sends a non-null snapshot', () => {
            // The real server (backend/socket/index.ts) never actually sends a literal `null` —
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

        it('stays pinned to death on every subsequent navigate/reconnect while dead (same simplification as ambush)', () => {
            const catalog = makeCatalog();
            useGameStore.getState().hydrate({ player: makePlayer({ dead: true }), catalog });
            expect(useGameStore.getState().screen).toBe('death');

            // Unlike ambush-era "browse freely" behavior, death is now an unconditional pin: any
            // attempt to navigate elsewhere while dead is silently redirected back to 'death' —
            // there's nowhere else a dead player is allowed to be, matching the plan's explicit
            // "same simplification as /battle" request.
            useGameStore.getState().navigate('highscores');
            expect(useGameStore.getState().screen).toBe('death');

            // A further reconnect where dead was already true before this hydrate must also
            // still land on 'death', not wherever the (irrelevant, since unreachable) screen
            // field happened to be.
            useGameStore.getState().hydrate({ player: makePlayer({ dead: true }), catalog });
            expect(useGameStore.getState().screen).toBe('death');
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
            // `lastBattle` is now the lighter, reconnect-safe shape (narrative/outcome/
            // ambushed/died/sound) — NOT the full ack object (which also carries player/flash,
            // never read off lastBattle by BattleScreen/AmbushBanner; they read store.player/
            // store.flash directly instead).
            expect(state.lastBattle).toEqual({
                narrative: result.narrative,
                outcome: result.outcome,
                ambushed: result.ambushed,
                died: result.died,
                sound: result.sound,
            });
            expect(state.flash).toBeNull();
            expect(state.notice).toBeNull();
        });
    });

    describe('hydrate — lastBattle persistence (Fix 4)', () => {
        it('populates lastBattle from PlayerSnapshot.lastBattle on a subsequent hydrate (reconnect after a real page reload)', () => {
            const catalog = makeCatalog();
            useGameStore.getState().hydrate({ player: makePlayer({ dead: false }), catalog });
            expect(useGameStore.getState().lastBattle).toBeNull();

            const persistedNarrative = {
                narrative: {
                    critLine: null, killLine: 'You slay a Goblin.', deflectionLine: 'Your armor deflects the blow.',
                    outcomeLine: 'You gain 10 XP.', ambushLine: 'Bandits leap from the treeline!',
                    fightPrompt: 'Fight them!', nextMove: 'Strike',
                },
                outcome: { enemiesKilled: 1, hpLost: 5, damageBlocked: 2, xpGained: 10, adenaGained: 3, isCritical: false, isLevelUp: false },
                ambushed: true,
                died: false,
                sound: 'ambush' as const,
            };

            // Simulates a real reconnect: no recordBattleResult ever ran in this "session" — the
            // narrative arrives purely via hydrate's PlayerSnapshot.lastBattle, exactly like a
            // fresh page load after having fought previously.
            useGameStore.getState().hydrate({
                player: makePlayer({ dead: false, ambushed: true, lastBattle: persistedNarrative }),
                catalog,
            });

            expect(useGameStore.getState().lastBattle).toEqual(persistedNarrative);
        });

        it('clears a stale lastBattle back to null when a reset lands (server already cleared lastBattleNarrative)', () => {
            const catalog = makeCatalog();
            const persistedNarrative = {
                narrative: {
                    critLine: null, killLine: 'k', deflectionLine: 'd', outcomeLine: 'o',
                    ambushLine: null, fightPrompt: null, nextMove: 'Strike',
                },
                outcome: { enemiesKilled: 1, hpLost: 1, damageBlocked: 0, xpGained: 1, adenaGained: 1, isCritical: false, isLevelUp: false },
                ambushed: false,
                died: true,
                sound: 'death' as const,
            };
            useGameStore.getState().hydrate({ player: makePlayer({ dead: true, lastBattle: persistedNarrative }), catalog });
            expect(useGameStore.getState().lastBattle).toEqual(persistedNarrative);

            const resetPlayer = makePlayer({ started: false, dead: false, name: null, raceId: null, lastBattle: null });
            useGameStore.getState().hydrate({ player: resetPlayer, catalog });

            expect(useGameStore.getState().lastBattle).toBeNull();
        });
    });

    describe('pin-to-battle invariant (ambushed screen === battle)', () => {
        it('navigate() while ambushed silently redirects to "battle" instead of the requested screen', () => {
            const catalog = makeCatalog();
            useGameStore.getState().hydrate({ player: makePlayer({ dead: false, ambushed: true }), catalog });

            useGameStore.getState().navigate('highscores');

            expect(useGameStore.getState().screen).toBe('battle');
        });

        it('hydrate() that flips ambushed to true immediately pins the screen to "battle", from whatever screen was previously active', () => {
            const catalog = makeCatalog();
            useGameStore.getState().hydrate({ player: makePlayer({ dead: false, ambushed: false }), catalog });
            useGameStore.getState().navigate('highscores');
            expect(useGameStore.getState().screen).toBe('highscores');

            useGameStore.getState().hydrate({ player: makePlayer({ dead: false, ambushed: true }), catalog });

            expect(useGameStore.getState().screen).toBe('battle');
        });

        it('applyUpdate() that flips ambushed to true immediately pins the screen to "battle"', () => {
            const catalog = makeCatalog();
            useGameStore.getState().hydrate({ player: makePlayer({ dead: false, ambushed: false }), catalog });
            useGameStore.getState().navigate('weapons');
            expect(useGameStore.getState().screen).toBe('weapons');

            useGameStore.getState().applyUpdate({ ambushed: true });

            expect(useGameStore.getState().screen).toBe('battle');
        });

        it('applyMutation() that flips ambushed to true immediately pins the screen to "battle"', () => {
            const catalog = makeCatalog();
            useGameStore.getState().hydrate({ player: makePlayer({ dead: false, ambushed: false }), catalog });
            useGameStore.getState().navigate('inn');
            expect(useGameStore.getState().screen).toBe('inn');

            useGameStore.getState().applyMutation(makePlayer({ ambushed: true }));

            expect(useGameStore.getState().screen).toBe('battle');
        });

        it('recordBattleResult() whose player is ambushed immediately pins the screen to "battle"', () => {
            const catalog = makeCatalog();
            useGameStore.getState().hydrate({ player: makePlayer({ dead: false, ambushed: false }), catalog });
            useGameStore.getState().navigate('armors');
            expect(useGameStore.getState().screen).toBe('armors');

            useGameStore.getState().recordBattleResult({
                player: makePlayer({ ambushed: true }),
                outcome: {
                    enemiesKilled: 1, hpLost: 5, damageBlocked: 2, xpGained: 10, adenaGained: 3,
                    isCritical: false, isLevelUp: false,
                },
                narrative: {
                    critLine: null, killLine: 'kill', deflectionLine: 'deflect',
                    outcomeLine: 'outcome', ambushLine: 'ambush!', fightPrompt: 'Fight!', nextMove: 'Strike',
                },
                ambushed: true,
                died: false,
                flash: null,
                sound: 'ambush',
            });

            expect(useGameStore.getState().screen).toBe('battle');
        });

        it('once ambushed resolves back to false, navigation works normally again', () => {
            const catalog = makeCatalog();
            useGameStore.getState().hydrate({ player: makePlayer({ dead: false, ambushed: true }), catalog });
            useGameStore.getState().navigate('highscores');
            expect(useGameStore.getState().screen).toBe('battle');

            useGameStore.getState().applyUpdate({ ambushed: false });
            useGameStore.getState().navigate('highscores');

            expect(useGameStore.getState().screen).toBe('highscores');
        });
    });

    describe('navigate() clears flash', () => {
        it('clears a lingering flash message when navigating to a different screen', () => {
            const catalog = makeCatalog();
            useGameStore.getState().hydrate({ player: makePlayer(), catalog });
            useGameStore.getState().applyMutation(makePlayer(), { text: 'You have bought a thing.', type: 'success' });
            expect(useGameStore.getState().flash).not.toBeNull();

            useGameStore.getState().navigate('home');

            expect(useGameStore.getState().flash).toBeNull();
        });
    });

    describe('navigate() fires battle:leave when leaving the Battle screen', () => {
        it('fires battle:leave when navigating away from "battle" to another screen', () => {
            const catalog = makeCatalog();
            useGameStore.getState().hydrate({ player: makePlayer({ ambushed: false }), catalog });
            useGameStore.getState().navigate('battle');
            requestMock.mockClear();

            useGameStore.getState().navigate('home');

            expect(requestMock).toHaveBeenCalledWith('battle:leave', {});
        });

        it('does not fire battle:leave when navigating between two non-battle screens', () => {
            const catalog = makeCatalog();
            useGameStore.getState().hydrate({ player: makePlayer({ ambushed: false }), catalog });
            useGameStore.getState().navigate('weapons');
            requestMock.mockClear();

            useGameStore.getState().navigate('home');

            expect(requestMock).not.toHaveBeenCalled();
        });

        it('does not fire battle:leave while ambushed — pinScreen keeps the player on "battle" regardless of the requested screen', () => {
            const catalog = makeCatalog();
            useGameStore.getState().hydrate({ player: makePlayer({ ambushed: true }), catalog });
            requestMock.mockClear();

            useGameStore.getState().navigate('home');
            expect(useGameStore.getState().screen).toBe('battle');

            expect(requestMock).not.toHaveBeenCalled();
        });

        it('does not fire battle:leave when re-navigating to "battle" itself (e.g. a repeat click)', () => {
            const catalog = makeCatalog();
            useGameStore.getState().hydrate({ player: makePlayer({ ambushed: false }), catalog });
            useGameStore.getState().navigate('battle');
            requestMock.mockClear();

            useGameStore.getState().navigate('battle');

            expect(requestMock).not.toHaveBeenCalled();
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
