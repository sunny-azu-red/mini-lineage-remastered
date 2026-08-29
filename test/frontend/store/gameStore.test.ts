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

        // Regression: PlayerSnapshot.revision is documented as monotonic specifically so an
        // out-of-order state:update push (increasingly possible with mutation broadcasts, the
        // periodic tick, and exact expiry timers all independently able to push for the same
        // session) can be detected and dropped — applyUpdate previously never checked this at
        // all, letting a stale push silently clobber fresher state.
        it('drops a push whose revision is older than the currently-held player\'s', () => {
            const catalog = makeCatalog();
            useGameStore.getState().hydrate({ player: makePlayer({ revision: 5, health: 80 }), catalog });

            useGameStore.getState().applyUpdate({ revision: 3, health: 999 });

            expect(useGameStore.getState().player?.health).toBe(80);
            expect(useGameStore.getState().player?.revision).toBe(5);
        });

        it('applies a push whose revision is the same as or newer than the currently-held player\'s', () => {
            const catalog = makeCatalog();
            useGameStore.getState().hydrate({ player: makePlayer({ revision: 5, health: 80 }), catalog });

            useGameStore.getState().applyUpdate({ revision: 6, health: 42 });

            expect(useGameStore.getState().player?.health).toBe(42);
            expect(useGameStore.getState().player?.revision).toBe(6);
        });

        it('applies a push with no revision field at all (never drops purely for its absence)', () => {
            const catalog = makeCatalog();
            useGameStore.getState().hydrate({ player: makePlayer({ revision: 5, health: 80 }), catalog });

            useGameStore.getState().applyUpdate({ health: 42 });

            expect(useGameStore.getState().player?.health).toBe(42);
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

    describe('navigate() reports the resolved screen via player:screen — the location-based signal syncZoneAuras uses (matching the old game\'s per-navigation zone.middleware.ts)', () => {
        it('fires player:screen with the new screen on every navigation', () => {
            const catalog = makeCatalog();
            useGameStore.getState().hydrate({ player: makePlayer({ ambushed: false }), catalog });
            requestMock.mockClear();

            useGameStore.getState().navigate('weapons');

            expect(requestMock).toHaveBeenCalledWith('player:screen', { screen: 'weapons' });
        });

        it('fires player:screen again for a second, different navigation', () => {
            const catalog = makeCatalog();
            useGameStore.getState().hydrate({ player: makePlayer({ ambushed: false }), catalog });
            useGameStore.getState().navigate('weapons');
            requestMock.mockClear();

            useGameStore.getState().navigate('home');

            expect(requestMock).toHaveBeenCalledWith('player:screen', { screen: 'home' });
        });

        it('does not fire player:screen when re-navigating to the screen it\'s already on (e.g. a repeat click)', () => {
            const catalog = makeCatalog();
            useGameStore.getState().hydrate({ player: makePlayer({ ambushed: false }), catalog });
            useGameStore.getState().navigate('battle');
            requestMock.mockClear();

            useGameStore.getState().navigate('battle');

            expect(requestMock).not.toHaveBeenCalled();
        });

        it('reports "battle" (not the requested screen) while ambushed, since pinScreen forces it there regardless', () => {
            const catalog = makeCatalog();
            // First hydrate ever with an ambushed player already resolves screen to 'battle'
            // directly (not via navigate()), so requesting 'home' here is a genuine change from
            // the caller's perspective even though pinScreen collapses it back to 'battle'.
            useGameStore.getState().hydrate({ player: makePlayer({ ambushed: false }), catalog });
            requestMock.mockClear();
            useGameStore.getState().applyUpdate({ ambushed: true });
            requestMock.mockClear();

            useGameStore.getState().navigate('home');

            expect(useGameStore.getState().screen).toBe('battle');
            expect(requestMock).not.toHaveBeenCalledWith('player:screen', { screen: 'home' });
        });

        // Regression: the acting tab's own navigate() call was firing player:screen and
        // discarding the response entirely, reasoning that "the server's broadcast keeps every
        // tab correct" — but registry.ts's broadcast for this mutation deliberately EXCLUDES the
        // acting socket (every mutating action does this), so the ack is the ONLY way this tab
        // itself ever learns its own aura just changed. Without applying it, the combat aura
        // never appeared on screens like Suicide until an unrelated action or a hard reload
        // happened to refresh it, even though the server-side state (and regen-blocking) was
        // already correct all along.
        it('applies the player:screen ack to its OWN store — the acting tab must see its own aura change, not just other tabs', async () => {
            const catalog = makeCatalog();
            useGameStore.getState().hydrate({ player: makePlayer({ ambushed: false, effects: [] }), catalog });
            requestMock.mockClear();

            const combatEffect = { id: 'combat', type: 'aura' as const, emoji: '⚔️', label: 'In Combat', tooltip: '' };
            const updatedPlayer = makePlayer({ ambushed: false, effects: [combatEffect] });
            requestMock.mockResolvedValueOnce({ ok: true, data: { player: updatedPlayer, flash: null } });

            useGameStore.getState().navigate('suicide');
            expect(useGameStore.getState().player?.effects).toEqual([]); // not yet — ack still in flight

            await new Promise(resolve => setTimeout(resolve, 0));

            expect(useGameStore.getState().player?.effects).toEqual([combatEffect]);
        });

        it('drops a player:screen ack that arrives after a fresher (higher-revision) update already landed', async () => {
            const catalog = makeCatalog();
            useGameStore.getState().hydrate({ player: makePlayer({ revision: 1, health: 80 }), catalog });
            requestMock.mockClear();

            requestMock.mockResolvedValueOnce({ ok: true, data: { player: makePlayer({ revision: 1, health: 999 }), flash: null } });
            useGameStore.getState().navigate('inn');

            // A different, fresher mutation lands first (e.g. a purchase's own ack).
            useGameStore.getState().applyMutation(makePlayer({ revision: 2, health: 42 }));

            await new Promise(resolve => setTimeout(resolve, 0));

            expect(useGameStore.getState().player?.health).toBe(42); // stale ack ignored
            expect(useGameStore.getState().player?.revision).toBe(2);
        });
    });

    describe('hydrate() reports the resolved screen via player:screen for a started player', () => {
        it('fires player:screen on the very first hydrate for a started player', () => {
            const catalog = makeCatalog();
            useGameStore.getState().hydrate({ player: makePlayer({ started: true, dead: false }), catalog });

            expect(requestMock).toHaveBeenCalledWith('player:screen', { screen: 'home' });
        });

        it('does not fire player:screen for a not-yet-started player', () => {
            const catalog = makeCatalog();
            useGameStore.getState().hydrate({ player: makePlayer({ started: false, dead: false, name: null }), catalog });

            expect(requestMock).not.toHaveBeenCalled();
        });

        it('fires player:screen again on a later reconnect, reflecting whatever screen it resolved to', () => {
            const catalog = makeCatalog();
            useGameStore.getState().hydrate({ player: makePlayer({ dead: false }), catalog });
            useGameStore.getState().navigate('highscores');
            requestMock.mockClear();

            useGameStore.getState().hydrate({ player: makePlayer({ dead: true }), catalog });

            expect(requestMock).toHaveBeenCalledWith('player:screen', { screen: 'death' });
        });

        // Same regression as navigate()'s equivalent test above: hydrate's own player:screen ack
        // must be applied, since a fresh page load's own aura (computed against whatever
        // currentScreen was PERSISTED from before this connection) can be stale relative to the
        // screen this hydrate just resolved to and reported.
        it('applies the player:screen ack to its own store after hydrating', async () => {
            const catalog = makeCatalog();
            const combatEffect = { id: 'combat', type: 'aura' as const, emoji: '⚔️', label: 'In Combat', tooltip: '' };
            requestMock.mockResolvedValueOnce({ ok: true, data: { player: makePlayer({ effects: [combatEffect] }), flash: null } });

            useGameStore.getState().hydrate({ player: makePlayer({ started: true, dead: false, effects: [] }), catalog });
            expect(useGameStore.getState().player?.effects).toEqual([]);

            await new Promise(resolve => setTimeout(resolve, 0));

            expect(useGameStore.getState().player?.effects).toEqual([combatEffect]);
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
