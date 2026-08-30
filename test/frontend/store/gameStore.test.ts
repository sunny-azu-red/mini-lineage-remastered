import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import type { HydratePayload } from '@shared/contract';
import { makeCatalog, makePlayer } from '../factories';

// The defaults this file's assertions were written against.
const localPlayer = (o: Partial<Parameters<typeof makePlayer>[0]> = {}) =>
    makePlayer({ effects: [ { id: 'e1', type: 'buff', emoji: '💪', label: 'Strength', tooltip: 'Strength (+5 Attack)' }, ], ...o });

// The defaults this file's assertions were written against.
const localCatalog = (o: Partial<Parameters<typeof makeCatalog>[0]> = {}) =>
    makeCatalog({ nameMinLength: 2, nameMaxLength: 16, ...o });

const { requestMock } = vi.hoisted(() => ({ requestMock: vi.fn() }));

vi.mock('@/socket/client', () => ({
    request: requestMock,
}));

const { useGameStore } = await import('@/store/gameStore');

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
        requestMock.mockResolvedValue({ ok: true, data: { player: localPlayer(), flash: null } });
        resetStore();
    });

    describe('hydrate — first hydrate this session', () => {
        it('picks the "start" screen when there is no player yet', () => {
            const payload: HydratePayload = { player: null, catalog: localCatalog() };
            useGameStore.getState().hydrate(payload);
            expect(useGameStore.getState().screen).toBe('start');
        });

        it('picks the "start" screen for a never-started player even when the server sends a non-null snapshot', () => {
            // The real server (backend/socket/index.ts) never actually sends a literal `null` —
            // a brand-new visitor's snapshot is `buildPlayerSnapshot({})`, i.e. a real object
            // with `started: false`. Regression guard for a real gap: `hydrate()` used to branch
            // on `p.player === null` instead of `.started`, which would have misrouted this
            // (extremely common — every first-time visitor) case to 'home'.
            const payload: HydratePayload = { player: localPlayer({ started: false, dead: false, name: null }), catalog: localCatalog() };
            useGameStore.getState().hydrate(payload);
            expect(useGameStore.getState().screen).toBe('start');
        });

        it('picks the "home" screen for a live player', () => {
            const payload: HydratePayload = { player: localPlayer({ dead: false }), catalog: localCatalog() };
            useGameStore.getState().hydrate(payload);
            expect(useGameStore.getState().screen).toBe('home');
        });

        it('picks the "death" screen for a dead player', () => {
            const payload: HydratePayload = { player: localPlayer({ dead: true }), catalog: localCatalog() };
            useGameStore.getState().hydrate(payload);
            expect(useGameStore.getState().screen).toBe('death');
        });

        /**
         * A deep link must be reported to the server exactly ONCE. Booting to 'home' and letting
         * useHistorySync correct it a round trip later made the server see two real navigations —
         * so a hard reload on /battle briefly classified the player as resting, and (once the
         * disengage countdown existed) armed and then cancelled one.
         */
        describe('resolves the boot screen from the URL', () => {
            afterEach(() => {
                window.history.replaceState(null, '', '/');
            });

            it('boots straight into a deep-linked screen, reporting it once and never "home" first', () => {
                window.history.replaceState(null, '', '/battle');

                useGameStore.getState().hydrate({ player: localPlayer({ dead: false }), catalog: localCatalog() });

                expect(useGameStore.getState().screen).toBe('battle');
                expect(requestMock).toHaveBeenCalledTimes(1);
                expect(requestMock).toHaveBeenCalledWith('player:screen', { screen: 'battle' });
            });

            it('still applies the access rules to what the URL asked for', () => {
                // /death offers "Play Again?", which would wipe a living character.
                window.history.replaceState(null, '', '/death');

                useGameStore.getState().hydrate({ player: localPlayer({ dead: false }), catalog: localCatalog() });

                expect(useGameStore.getState().screen).toBe('home');
                expect(requestMock).toHaveBeenCalledWith('player:screen', { screen: 'home' });
            });

            it('boots a visitor with no character into an allowlisted deep link', () => {
                window.history.replaceState(null, '', '/statistics');

                useGameStore.getState().hydrate({ player: localPlayer({ started: false, name: null }), catalog: localCatalog() });

                expect(useGameStore.getState().screen).toBe('statistics');
                // requireStarted would reject a report from a character-less visitor.
                expect(requestMock).not.toHaveBeenCalled();
            });

            it('resolves a race-filtered highscores slug to the highscores screen', () => {
                window.history.replaceState(null, '', '/highscores/human');

                useGameStore.getState().hydrate({ player: localPlayer({ dead: false }), catalog: localCatalog() });

                expect(useGameStore.getState().screen).toBe('highscores');
            });

            it('ignores the URL on a later hydrate, keeping the screen the player is actually on', () => {
                useGameStore.getState().hydrate({ player: localPlayer({ dead: false }), catalog: localCatalog() });
                useGameStore.getState().navigate('inn');
                window.history.replaceState(null, '', '/battle');
                requestMock.mockClear();

                // A reconnect re-hydrates; it must not teleport the player to whatever the bar says.
                useGameStore.getState().hydrate({ player: localPlayer({ dead: false }), catalog: localCatalog() });

                expect(useGameStore.getState().screen).toBe('inn');
            });
        });
    });

    describe('hydrate — reconnect (subsequent hydrate)', () => {
        it('preserves the current screen on an ordinary reconnect', () => {
            const catalog = localCatalog();
            useGameStore.getState().hydrate({ player: localPlayer({ dead: false }), catalog });
            useGameStore.getState().navigate('battle');

            // Reconnect: player state unchanged (still alive, ambushed even) — screen must NOT
            // be clobbered back to 'home'. This is the core "refresh mid-ambush is harmless"
            // invariant.
            useGameStore.getState().hydrate({ player: localPlayer({ dead: false, ambushed: true }), catalog });

            expect(useGameStore.getState().screen).toBe('battle');
        });

        it('jumps to "death" when a reconnect reveals the player just died', () => {
            const catalog = localCatalog();
            useGameStore.getState().hydrate({ player: localPlayer({ dead: false }), catalog });
            useGameStore.getState().navigate('battle');

            useGameStore.getState().hydrate({ player: localPlayer({ dead: true }), catalog });

            expect(useGameStore.getState().screen).toBe('death');
        });

        it('routes back to "start" when a reset (game:restart / highscore submit) lands', () => {
            const catalog = localCatalog();
            useGameStore.getState().hydrate({ player: localPlayer({ dead: true }), catalog });
            expect(useGameStore.getState().screen).toBe('death');

            // The server never sends a literal `null` player (see hydrate()'s own comment) —
            // a reset player is a real PlayerSnapshot with `started: false` and every other
            // field back at its empty default (mirrors buildPlayerSnapshot's EMPTY_SNAPSHOT_DEFAULTS).
            const resetPlayer = localPlayer({ started: false, dead: false, name: null, raceId: null });
            useGameStore.getState().hydrate({ player: resetPlayer, catalog });

            expect(useGameStore.getState().screen).toBe('start');
        });

        it('stays pinned to death on every subsequent navigate/reconnect while dead (same simplification as ambush)', () => {
            const catalog = localCatalog();
            useGameStore.getState().hydrate({ player: localPlayer({ dead: true }), catalog });
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
            useGameStore.getState().hydrate({ player: localPlayer({ dead: true }), catalog });
            expect(useGameStore.getState().screen).toBe('death');
        });
    });

    describe('applyUpdate', () => {
        it('shallow-merges without dropping unrelated fields', () => {
            const catalog = localCatalog();
            useGameStore.getState().hydrate({ player: localPlayer({ health: 50, effects: [
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
            const catalog = localCatalog();
            useGameStore.getState().hydrate({ player: localPlayer({ revision: 5, health: 80 }), catalog });

            useGameStore.getState().applyUpdate({ revision: 3, health: 999 });

            expect(useGameStore.getState().player?.health).toBe(80);
            expect(useGameStore.getState().player?.revision).toBe(5);
        });

        it('applies a push whose revision is the same as or newer than the currently-held player\'s', () => {
            const catalog = localCatalog();
            useGameStore.getState().hydrate({ player: localPlayer({ revision: 5, health: 80 }), catalog });

            useGameStore.getState().applyUpdate({ revision: 6, health: 42 });

            expect(useGameStore.getState().player?.health).toBe(42);
            expect(useGameStore.getState().player?.revision).toBe(6);
        });

        it('applies a push with no revision field at all (never drops purely for its absence)', () => {
            const catalog = localCatalog();
            useGameStore.getState().hydrate({ player: localPlayer({ revision: 5, health: 80 }), catalog });

            useGameStore.getState().applyUpdate({ health: 42 });

            expect(useGameStore.getState().player?.health).toBe(42);
        });
    });

    describe('applyMutation', () => {
        it('replaces player wholesale and sets flash, clearing any stale notice', () => {
            useGameStore.getState().setNotice({ code: 'RATE_LIMITED', message: 'slow down' });
            const newPlayer = localPlayer({ adena: 999 });

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
            const player = localPlayer({ health: 42 });
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
            const catalog = localCatalog();
            useGameStore.getState().hydrate({ player: localPlayer({ dead: false }), catalog });
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
                player: localPlayer({ dead: false, ambushed: true, lastBattle: persistedNarrative }),
                catalog,
            });

            expect(useGameStore.getState().lastBattle).toEqual(persistedNarrative);
        });

        it('clears a stale lastBattle back to null when a reset lands (server already cleared lastBattleNarrative)', () => {
            const catalog = localCatalog();
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
            useGameStore.getState().hydrate({ player: localPlayer({ dead: true, lastBattle: persistedNarrative }), catalog });
            expect(useGameStore.getState().lastBattle).toEqual(persistedNarrative);

            const resetPlayer = localPlayer({ started: false, dead: false, name: null, raceId: null, lastBattle: null });
            useGameStore.getState().hydrate({ player: resetPlayer, catalog });

            expect(useGameStore.getState().lastBattle).toBeNull();
        });
    });

    describe('pin-to-battle invariant (ambushed screen === battle)', () => {
        it('navigate() while ambushed silently redirects to "battle" instead of the requested screen', () => {
            const catalog = localCatalog();
            useGameStore.getState().hydrate({ player: localPlayer({ dead: false, ambushed: true }), catalog });

            useGameStore.getState().navigate('highscores');

            expect(useGameStore.getState().screen).toBe('battle');
        });

        it('hydrate() that flips ambushed to true immediately pins the screen to "battle", from whatever screen was previously active', () => {
            const catalog = localCatalog();
            useGameStore.getState().hydrate({ player: localPlayer({ dead: false, ambushed: false }), catalog });
            useGameStore.getState().navigate('highscores');
            expect(useGameStore.getState().screen).toBe('highscores');

            useGameStore.getState().hydrate({ player: localPlayer({ dead: false, ambushed: true }), catalog });

            expect(useGameStore.getState().screen).toBe('battle');
        });

        it('applyUpdate() that flips ambushed to true immediately pins the screen to "battle"', () => {
            const catalog = localCatalog();
            useGameStore.getState().hydrate({ player: localPlayer({ dead: false, ambushed: false }), catalog });
            useGameStore.getState().navigate('weapons');
            expect(useGameStore.getState().screen).toBe('weapons');

            useGameStore.getState().applyUpdate({ ambushed: true });

            expect(useGameStore.getState().screen).toBe('battle');
        });

        it('applyMutation() that flips ambushed to true immediately pins the screen to "battle"', () => {
            const catalog = localCatalog();
            useGameStore.getState().hydrate({ player: localPlayer({ dead: false, ambushed: false }), catalog });
            useGameStore.getState().navigate('inn');
            expect(useGameStore.getState().screen).toBe('inn');

            useGameStore.getState().applyMutation(localPlayer({ ambushed: true }));

            expect(useGameStore.getState().screen).toBe('battle');
        });

        it('recordBattleResult() whose player is ambushed immediately pins the screen to "battle"', () => {
            const catalog = localCatalog();
            useGameStore.getState().hydrate({ player: localPlayer({ dead: false, ambushed: false }), catalog });
            useGameStore.getState().navigate('armors');
            expect(useGameStore.getState().screen).toBe('armors');

            useGameStore.getState().recordBattleResult({
                player: localPlayer({ ambushed: true }),
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
            const catalog = localCatalog();
            useGameStore.getState().hydrate({ player: localPlayer({ dead: false, ambushed: true }), catalog });
            useGameStore.getState().navigate('highscores');
            expect(useGameStore.getState().screen).toBe('battle');

            useGameStore.getState().applyUpdate({ ambushed: false });
            useGameStore.getState().navigate('highscores');

            expect(useGameStore.getState().screen).toBe('highscores');
        });
    });

    describe('navigate() clears flash', () => {
        it('clears a lingering flash message when navigating to a different screen', () => {
            const catalog = localCatalog();
            useGameStore.getState().hydrate({ player: localPlayer(), catalog });
            useGameStore.getState().applyMutation(localPlayer(), { text: 'You have bought a thing.', type: 'success' });
            expect(useGameStore.getState().flash).not.toBeNull();

            useGameStore.getState().navigate('home');

            expect(useGameStore.getState().flash).toBeNull();
        });
    });

    describe('navigate() reports the resolved screen via player:screen — the location-based signal syncZoneAuras uses (matching the old game\'s per-navigation zone.middleware.ts)', () => {
        it('fires player:screen with the new screen on every navigation', () => {
            const catalog = localCatalog();
            useGameStore.getState().hydrate({ player: localPlayer({ ambushed: false }), catalog });
            requestMock.mockClear();

            useGameStore.getState().navigate('weapons');

            expect(requestMock).toHaveBeenCalledWith('player:screen', { screen: 'weapons' });
        });

        it('fires player:screen again for a second, different navigation', () => {
            const catalog = localCatalog();
            useGameStore.getState().hydrate({ player: localPlayer({ ambushed: false }), catalog });
            useGameStore.getState().navigate('weapons');
            requestMock.mockClear();

            useGameStore.getState().navigate('home');

            expect(requestMock).toHaveBeenCalledWith('player:screen', { screen: 'home' });
        });

        // A player with no character has no zone to classify, and the server's `player:screen`
        // handler is guarded by requireStarted — so firing it anyway is guaranteed to be rejected
        // with NOT_STARTED and logged server-side as `player:screen = error`. This is reachable
        // from the pre-character screens (Game Start, Statistics, Races, Highscores), e.g. opening
        // The Tome of Lore and then clicking the header to go back.
        it('does not fire player:screen when navigating with no character yet', () => {
            const catalog = localCatalog();
            useGameStore.getState().hydrate({ player: localPlayer({ started: false, name: null }), catalog });
            requestMock.mockClear();

            useGameStore.getState().navigate('statistics');
            useGameStore.getState().navigate('start');

            expect(requestMock).not.toHaveBeenCalled();
            // The navigation itself must still work — only the server report is suppressed.
            expect(useGameStore.getState().screen).toBe('start');
        });

        it('still navigates an unstarted player between the public screens', () => {
            const catalog = localCatalog();
            useGameStore.getState().hydrate({ player: localPlayer({ started: false, name: null }), catalog });

            useGameStore.getState().navigate('races');
            expect(useGameStore.getState().screen).toBe('races');

            useGameStore.getState().navigate('highscores');
            expect(useGameStore.getState().screen).toBe('highscores');
        });

        // Highscores stays open to a started player — the old app allowed it, and the Hall of
        // Champions is linked from Home.
        it('still reaches and reports highscores for a player who HAS started', () => {
            const catalog = localCatalog();
            useGameStore.getState().hydrate({ player: localPlayer({ started: true, dead: false, ambushed: false }), catalog });
            requestMock.mockClear();

            useGameStore.getState().navigate('highscores');

            expect(useGameStore.getState().screen).toBe('highscores');
            expect(requestMock).toHaveBeenCalledWith('player:screen', { screen: 'highscores' });
        });

        // Statistics and Races belong to character creation. The old cheatMiddleware redirected a
        // started player away from both, and pinScreen restores that.
        it.each(['statistics', 'races'] as const)(
            'redirects a started player away from %s to home',
            (destination) => {
                const catalog = localCatalog();
                useGameStore.getState().hydrate({ player: localPlayer({ started: true, dead: false, ambushed: false }), catalog });
                useGameStore.getState().navigate('inn');
                requestMock.mockClear();

                useGameStore.getState().navigate(destination);

                expect(useGameStore.getState().screen).toBe('home');
                // The report carries where they actually ARE, never where they asked to go.
                expect(requestMock).toHaveBeenCalledWith('player:screen', { screen: 'home' });
                expect(requestMock).not.toHaveBeenCalledWith('player:screen', { screen: destination });
            },
        );

        it('does not fire player:screen when re-navigating to the screen it\'s already on (e.g. a repeat click)', () => {
            const catalog = localCatalog();
            useGameStore.getState().hydrate({ player: localPlayer({ ambushed: false }), catalog });
            useGameStore.getState().navigate('battle');
            requestMock.mockClear();

            useGameStore.getState().navigate('battle');

            expect(requestMock).not.toHaveBeenCalled();
        });

        it('reports "battle" (not the requested screen) while ambushed, since pinScreen forces it there regardless', () => {
            const catalog = localCatalog();
            // First hydrate ever with an ambushed player already resolves screen to 'battle'
            // directly (not via navigate()), so requesting 'home' here is a genuine change from
            // the caller's perspective even though pinScreen collapses it back to 'battle'.
            useGameStore.getState().hydrate({ player: localPlayer({ ambushed: false }), catalog });
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
            const catalog = localCatalog();
            useGameStore.getState().hydrate({ player: localPlayer({ ambushed: false, effects: [] }), catalog });
            requestMock.mockClear();

            const combatEffect = { id: 'combat', type: 'aura' as const, emoji: '⚔️', label: 'In Combat', tooltip: '' };
            const updatedPlayer = localPlayer({ ambushed: false, effects: [combatEffect] });
            requestMock.mockResolvedValueOnce({ ok: true, data: { player: updatedPlayer, flash: null } });

            useGameStore.getState().navigate('suicide');
            expect(useGameStore.getState().player?.effects).toEqual([]); // not yet — ack still in flight

            await new Promise(resolve => setTimeout(resolve, 0));

            expect(useGameStore.getState().player?.effects).toEqual([combatEffect]);
        });

        it('drops a player:screen ack that arrives after a fresher (higher-revision) update already landed', async () => {
            const catalog = localCatalog();
            useGameStore.getState().hydrate({ player: localPlayer({ revision: 1, health: 80 }), catalog });
            requestMock.mockClear();

            requestMock.mockResolvedValueOnce({ ok: true, data: { player: localPlayer({ revision: 1, health: 999 }), flash: null } });
            useGameStore.getState().navigate('inn');

            // A different, fresher mutation lands first (e.g. a purchase's own ack).
            useGameStore.getState().applyMutation(localPlayer({ revision: 2, health: 42 }));

            await new Promise(resolve => setTimeout(resolve, 0));

            expect(useGameStore.getState().player?.health).toBe(42); // stale ack ignored
            expect(useGameStore.getState().player?.revision).toBe(2);
        });
    });

    describe('hydrate() reports the resolved screen via player:screen for a started player', () => {
        it('fires player:screen on the very first hydrate for a started player', () => {
            const catalog = localCatalog();
            useGameStore.getState().hydrate({ player: localPlayer({ started: true, dead: false }), catalog });

            expect(requestMock).toHaveBeenCalledWith('player:screen', { screen: 'home' });
        });

        it('does not fire player:screen for a not-yet-started player', () => {
            const catalog = localCatalog();
            useGameStore.getState().hydrate({ player: localPlayer({ started: false, dead: false, name: null }), catalog });

            expect(requestMock).not.toHaveBeenCalled();
        });

        it('fires player:screen again on a later reconnect, reflecting whatever screen it resolved to', () => {
            const catalog = localCatalog();
            useGameStore.getState().hydrate({ player: localPlayer({ dead: false }), catalog });
            useGameStore.getState().navigate('highscores');
            requestMock.mockClear();

            useGameStore.getState().hydrate({ player: localPlayer({ dead: true }), catalog });

            expect(requestMock).toHaveBeenCalledWith('player:screen', { screen: 'death' });
        });

        // Same regression as navigate()'s equivalent test above: hydrate's own player:screen ack
        // must be applied, since a fresh page load's own aura (computed against whatever
        // currentScreen was PERSISTED from before this connection) can be stale relative to the
        // screen this hydrate just resolved to and reported.
        it('applies the player:screen ack to its own store after hydrating', async () => {
            const catalog = localCatalog();
            const combatEffect = { id: 'combat', type: 'aura' as const, emoji: '⚔️', label: 'In Combat', tooltip: '' };
            requestMock.mockResolvedValueOnce({ ok: true, data: { player: localPlayer({ effects: [combatEffect] }), flash: null } });

            useGameStore.getState().hydrate({ player: localPlayer({ started: true, dead: false, effects: [] }), catalog });
            expect(useGameStore.getState().player?.effects).toEqual([]);

            await new Promise(resolve => setTimeout(resolve, 0));

            expect(useGameStore.getState().player?.effects).toEqual([combatEffect]);
        });
    });

    describe('simple setters', () => {
        it('setFlash replaces the flash, including clearing it back to null', () => {
            useGameStore.getState().setFlash({ text: 'You gained 10 XP!', type: 'success' });
            expect(useGameStore.getState().flash).toEqual({ text: 'You gained 10 XP!', type: 'success' });

            useGameStore.getState().setFlash(null);
            expect(useGameStore.getState().flash).toBeNull();
        });

        it('setNotice replaces the notice, including clearing it back to null (the dismiss button)', () => {
            useGameStore.getState().setNotice({ code: 'RATE_LIMITED', message: 'Too many requests.', retryAfterMs: 4200 });
            expect(useGameStore.getState().notice).toEqual({ code: 'RATE_LIMITED', message: 'Too many requests.', retryAfterMs: 4200 });

            useGameStore.getState().setNotice(null);
            expect(useGameStore.getState().notice).toBeNull();
        });

        it('setStatus moves the connection status across all three values', () => {
            useGameStore.getState().setStatus('ready');
            expect(useGameStore.getState().status).toBe('ready');

            useGameStore.getState().setStatus('disconnected');
            expect(useGameStore.getState().status).toBe('disconnected');

            useGameStore.getState().setStatus('connecting');
            expect(useGameStore.getState().status).toBe('connecting');
        });

        it('none of them disturb the rest of the state', () => {
            const player = localPlayer();
            useGameStore.setState({ player, catalog: localCatalog(), screen: 'inn' }, false);

            useGameStore.getState().setFlash({ text: 'Ate!', type: 'success' });
            useGameStore.getState().setNotice({ code: 'INTERNAL', message: 'boom' });
            useGameStore.getState().setStatus('disconnected');

            expect(useGameStore.getState().player).toBe(player);
            expect(useGameStore.getState().screen).toBe('inn');
        });
    });

    describe('toggleSound', () => {
        it('flips soundEnabled', () => {
            const before = useGameStore.getState().soundEnabled;
            useGameStore.getState().toggleSound();
            expect(useGameStore.getState().soundEnabled).toBe(!before);
        });

        it('persists the new preference under the shared localStorage key', () => {
            const setItemSpy = vi.spyOn(Storage.prototype, 'setItem');
            useGameStore.setState({ soundEnabled: true }, false);

            useGameStore.getState().toggleSound();

            expect(setItemSpy).toHaveBeenCalledWith('mini_sound_enabled', 'false');
            setItemSpy.mockRestore();
        });

        // localStorage.setItem throws in private-mode Safari and when the quota is exhausted —
        // the preference just doesn't persist, which must never break the in-memory toggle.
        it('still flips in memory when localStorage.setItem throws', () => {
            const setItemSpy = vi.spyOn(Storage.prototype, 'setItem').mockImplementation(() => {
                throw new Error('QuotaExceededError');
            });
            const before = useGameStore.getState().soundEnabled;

            expect(() => useGameStore.getState().toggleSound()).not.toThrow();
            expect(useGameStore.getState().soundEnabled).toBe(!before);

            setItemSpy.mockRestore();
        });
    });

    // The initial value is read once, at module-evaluation time — so each case here re-imports
    // the store with localStorage stubbed differently (vi.resetModules discards the cached
    // instance; the vi.mock('@/socket/client') registration above still applies to the fresh one).
    describe('initial soundEnabled, read from localStorage at module load', () => {
        afterEach(() => {
            vi.restoreAllMocks();
            vi.resetModules();
        });

        async function freshStore() {
            vi.resetModules();
            const mod = await import('@/store/gameStore');
            return mod.useGameStore;
        }

        it('defaults to true when nothing has been stored yet', async () => {
            vi.spyOn(Storage.prototype, 'getItem').mockReturnValue(null);

            expect((await freshStore()).getState().soundEnabled).toBe(true);
        });

        it('is false only for the literal stored string "false"', async () => {
            vi.spyOn(Storage.prototype, 'getItem').mockReturnValue('false');

            expect((await freshStore()).getState().soundEnabled).toBe(false);
        });

        // localStorage access itself throws in private-mode Safari (and doesn't exist at all in a
        // plain 'node' test environment) — sound must simply default to on rather than crashing
        // the entire store's creation.
        it('falls back to true when localStorage access throws outright', async () => {
            vi.spyOn(Storage.prototype, 'getItem').mockImplementation(() => {
                throw new Error('SecurityError: access denied');
            });

            expect((await freshStore()).getState().soundEnabled).toBe(true);
        });
    });
});

describe('hydrate — null player snapshots', () => {
    it('treats a later hydrate carrying a null player as a reset back to start', () => {
        // HydratePayload.player is typed nullable for API generality; the server sends a
        // `{ started: false }` snapshot in practice, but a literal null must not crash or
        // strand the client on a screen that needs a character.
        useGameStore.getState().hydrate({ player: makePlayer({ started: true }), catalog: makeCatalog() });
        useGameStore.getState().navigate('inn');
        expect(useGameStore.getState().screen).toBe('inn');

        useGameStore.getState().hydrate({ player: null, catalog: makeCatalog() });

        expect(useGameStore.getState().player).toBeNull();
        expect(useGameStore.getState().screen).toBe('start');
        expect(useGameStore.getState().lastBattle).toBeNull();
    });

    it('stays on start when the very first hydrate carries a null player', () => {
        useGameStore.getState().hydrate({ player: null, catalog: makeCatalog() });

        expect(useGameStore.getState().screen).toBe('start');
    });
});

describe('applyMutation — atomic screen moves', () => {
    // Mid-transition callers (game start, suicide) must move screen in the SAME update that
    // commits the new snapshot. Calling navigate() first would pin against the OLD player still
    // in the store and get redirected.
    it('moves to the given screen using the NEW player, not the one still in the store', () => {
        useGameStore.getState().hydrate({ player: localPlayer({ started: false, name: null }), catalog: localCatalog() });
        expect(useGameStore.getState().screen).toBe('start');

        useGameStore.getState().applyMutation(localPlayer({ started: true, dead: false }), null, 'home');

        expect(useGameStore.getState().screen).toBe('home');
    });

    it('keeps the flash that came with the mutation', () => {
        useGameStore.getState().hydrate({ player: localPlayer({ started: false, name: null }), catalog: localCatalog() });
        const flash = { text: 'Welcome, Heir!', type: 'info' as const };

        useGameStore.getState().applyMutation(localPlayer({ started: true, dead: false }), flash, 'home');

        expect(useGameStore.getState().flash).toEqual(flash);
        expect(useGameStore.getState().screen).toBe('home');
    });

    it('moves a freshly-dead player to the death screen', () => {
        useGameStore.getState().hydrate({ player: localPlayer({ dead: false }), catalog: localCatalog() });
        useGameStore.getState().navigate('suicide');

        useGameStore.getState().applyMutation(localPlayer({ dead: true }), null, 'death');

        expect(useGameStore.getState().screen).toBe('death');
    });

    // The screen is a request, not a command — pinScreen still has the last word.
    it('still pins the requested screen against the rules', () => {
        useGameStore.getState().hydrate({ player: localPlayer({ dead: false }), catalog: localCatalog() });

        useGameStore.getState().applyMutation(localPlayer({ dead: true }), null, 'home');

        expect(useGameStore.getState().screen).toBe('death');
    });

    it('leaves the screen alone when none is given', () => {
        useGameStore.getState().hydrate({ player: localPlayer({ dead: false }), catalog: localCatalog() });
        useGameStore.getState().navigate('inn');

        useGameStore.getState().applyMutation(localPlayer({ dead: false, adena: 5 }));

        expect(useGameStore.getState().screen).toBe('inn');
    });
});

