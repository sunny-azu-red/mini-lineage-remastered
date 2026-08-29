import { create } from 'zustand';
import { request } from '@/socket/client';
import type {
    PlayerSnapshot,
    GameCatalog,
    FlashView,
    SocketErrorPayload,
    BattleFightResult,
    BattleNarrativeSnapshot,
    HydratePayload,
    ScreenId,
} from '@shared/contract';

export type { ScreenId };

const SOUND_STORAGE_KEY = 'mini_sound_enabled';

/**
 * Matches public/js/audio.js line ~10 exactly: default to true unless the stored value is
 * literally the string 'false'. Wrapped in try/catch — localStorage can throw in private-mode
 * Safari, and simply doesn't exist in the plain Vitest 'node' test environment this store's
 * pure-logic tests run under.
 */
function readStoredSoundEnabled(): boolean {
    try {
        return localStorage.getItem(SOUND_STORAGE_KEY) !== 'false';
    } catch {
        return true;
    }
}

function writeStoredSoundEnabled(enabled: boolean): void {
    try {
        localStorage.setItem(SOUND_STORAGE_KEY, enabled ? 'true' : 'false');
    } catch {
        // Preference just won't persist this session — non-fatal.
    }
}

/**
 * The screen is pinned to 'battle' whenever the player is ambushed, or to 'death' whenever the
 * player is dead — there is no other screen to reach in either case, so this is applied at the
 * end of every action that sets `screen` and/or `player`, using whatever the FINAL `player` value
 * of that update is. This keeps both invariants true atomically after every single state
 * transition (navigation, hydrate/reconnect, a shop/battle mutation, a pushed update), not just
 * some of them — and it's what lets the header/character-name link stay unconditionally
 * clickable now: clicking them while ambushed or dead just harmlessly redirects right back.
 */
function pinScreen(screen: ScreenId, player: PlayerSnapshot | null): ScreenId {
    if (player?.ambushed)
        return 'battle';
    if (player?.dead)
        return 'death';
    return screen;
}

/**
 * Shared by every action that receives a new `player` value (`hydrate`, `applyUpdate` — NOT
 * `applyMutation`/`recordBattleResult`, whose actions never transition FROM started TO unstarted)
 * so the "a reset just landed, route back to 'start'" transition is detected identically no
 * matter which path the update arrives through. This matters because a mutating action's own
 * ack (processed via `hydrate`/`applyMutation`) and the server's `state:update` push for that
 * SAME mutation (processed via `applyUpdate`, still received by every OTHER tab on the session)
 * can arrive in either order — if only one of the two paths knew how to detect the transition,
 * whichever one lost the race would silently leave the screen stuck (see git history: the
 * game:restart screen-freeze bug).
 */
function deriveScreenAfterPlayerChange(
    prevPlayer: PlayerSnapshot | null,
    nextPlayer: PlayerSnapshot | null,
    currentScreen: ScreenId,
): ScreenId {
    const wasStarted = prevPlayer?.started ?? false;
    const isStarted = nextPlayer?.started ?? false;

    const screen = wasStarted && !isStarted ? 'start' : currentScreen;

    return pinScreen(screen, nextPlayer);
}

export interface GameStore {
    status: 'connecting' | 'ready' | 'disconnected';
    player: PlayerSnapshot | null;
    catalog: GameCatalog | null;
    screen: ScreenId;
    highscoreRaceFilter: number | null;
    flash: FlashView | null;
    /**
     * The lighter, reconnect-safe narrative shape (`{narrative, outcome, ambushed, died,
     * sound}`) — NOT the full `BattleFightResult` ack, which also carries `player`/`flash`
     * (those always come straight from `store.player`/`store.flash`, never read off this field
     * by `BattleScreen`). Populated by the live `battle:fight` ack
     * (`recordBattleResult`) AND by every `hydrate()` from `PlayerSnapshot.lastBattle` — so a
     * real page reload/reconnect shows the true last-fight narrative instead of a placeholder.
     */
    lastBattle: BattleNarrativeSnapshot | null;
    notice: SocketErrorPayload | null;
    soundEnabled: boolean;

    hydrate(p: HydratePayload): void;
    applyUpdate(p: Partial<PlayerSnapshot>): void;
    applyMutation(player: PlayerSnapshot, flash?: FlashView | null): void;
    /**
     * `battle:fight`'s ack carries strictly more than a `MutationResult` (outcome, narrative,
     * ambushed/died flags, a resolved sound) — this is the dedicated setter for it, alongside
     * `applyMutation`, rather than overloading that one's signature. Also stamps `lastBattle` so
     * `BattleScreen` can render the fight's narrative, and clears `notice` exactly like
     * `applyMutation` does.
     */
    recordBattleResult(result: BattleFightResult): void;
    /**
     * `raceFilter: undefined` (or omitting `opts` entirely) leaves the current filter alone;
     * `raceFilter: null` explicitly clears it (HighscoresScreen's "All" tab); `raceFilter: <id>`
     * sets it. This three-way distinction is why the field is `number | null | undefined` rather
     * than just `number` — the store's own implementation already handled `null` correctly via
     * its `!== undefined` check, this only widens the type to let callers pass it.
     */
    navigate(screen: ScreenId, opts?: { raceFilter?: number | null }): void;
    setFlash(f: FlashView | null): void;
    setNotice(n: SocketErrorPayload | null): void;
    setStatus(s: GameStore['status']): void;
    toggleSound(): void;
}

export const useGameStore = create<GameStore>((set, get) => ({
    status: 'connecting',
    player: null,
    catalog: null,
    screen: 'start',
    highscoreRaceFilter: null,
    flash: null,
    lastBattle: null,
    notice: null,
    soundEnabled: readStoredSoundEnabled(),

    hydrate(p) {
        set(state => {
            // `catalog` is null ONLY before the very first hydrate this store has ever received
            // (every HydratePayload carries a non-null GameCatalog) — so it doubles as the
            // "is this the first hydrate this session" flag without a separate tracked field.
            const isFirstHydrateEver = state.catalog === null;
            // NOTE: the server (src/socket/index.ts's connection handler) always sends a
            // non-null PlayerSnapshot — even for a session with no character yet, it's
            // `buildPlayerSnapshot({})`, i.e. `{ started: false, ... }` — never a literal
            // `null`. `HydratePayload.player` is typed `PlayerSnapshot | null` for API
            // generality (and so `game:restart`'s reset-in-place result composes cleanly), but
            // `started` — not null-ness — is the real "has a character" signal on both the
            // very first hydrate and every subsequent one.
            const screen = isFirstHydrateEver
                ? pinScreen(p.player?.started ? 'home' : 'start', p.player)
                : deriveScreenAfterPlayerChange(state.player, p.player, state.screen);

            // Reports the resolved screen so the server's zone-aura classification
            // (syncZoneAuras, matching the old game's URL-path-based zone.middleware.ts) is
            // correct immediately on connect/reconnect — hydrate() itself stays a pure read (this
            // fires a SEPARATE, real, tracked action as a reaction to what it resolved, the same
            // pattern navigate() below uses). The ack's player snapshot IS applied (via
            // applyUpdate, revision-guarded) — registry.ts's broadcast for this mutation
            // deliberately excludes the acting socket, so the ack is the ONLY way this tab
            // itself ever learns its own aura just changed; without applying it, this client
            // would keep showing the aura from before this hydrate until some unrelated later
            // push happened to refresh it (or a hard reload re-hydrated from scratch).
            if (p.player?.started)
                void request('player:screen', { screen }).then(res => {
                    // `res.data.player` is defensively checked (not just `res.ok`): a malformed
                    // or unexpected response must never be able to crash applyUpdate.
                    if (res.ok && res.data.player)
                        get().applyUpdate(res.data.player);
                });

            // Sync unconditionally (including to `null`) on EVERY hydrate, not just the first —
            // `PlayerSnapshot.lastBattle` is now the server-persisted source of truth, so a
            // reconnect must reflect it exactly: a genuine last-fight narrative on any reconnect
            // after fighting, but also back to `null` after a reset (game:restart/highscore
            // submit already clears `lastBattleNarrative` server-side) rather than leaving a
            // stale narrative from the previous character on screen.
            const lastBattle: BattleNarrativeSnapshot | null = p.player?.lastBattle ?? null;

            return { player: p.player, catalog: p.catalog, screen, lastBattle };
        });
    },

    applyUpdate(p) {
        set(state => {
            if (!state.player || !p)
                return {};
            // Drop an out-of-order push: with mutation broadcasts, the periodic tick, and exact
            // expiry timers all independently able to emit `state:update` for the same session,
            // an older one can land after a newer one. `PlayerSnapshot.revision` is documented as
            // monotonic specifically so this can be detected — without this guard a stale push
            // would silently clobber fresher state (including `effects`), which is exactly the
            // kind of "aura is strange" symptom a race like this produces.
            if (p.revision !== undefined && state.player.revision !== undefined && p.revision < state.player.revision)
                return {};
            const player = { ...state.player, ...p };
            return { player, screen: deriveScreenAfterPlayerChange(state.player, player, state.screen) };
        });
    },

    applyMutation(player, flash = null) {
        set(state => ({ player, flash, notice: null, screen: pinScreen(state.screen, player) }));
    },

    recordBattleResult(result) {
        set(state => ({
            player: result.player,
            flash: result.flash,
            lastBattle: {
                narrative: result.narrative,
                outcome: result.outcome,
                ambushed: result.ambushed,
                died: result.died,
                sound: result.sound,
            },
            notice: null,
            screen: pinScreen(state.screen, result.player),
        }));
    },

    navigate(screen, opts) {
        const state = get();
        const nextScreen = pinScreen(screen, state.player);

        // Tells the server which screen this is, so syncZoneAuras (player.service.ts) can
        // classify combat/resting purely from location — exactly like the old game's
        // URL-path-based zone.middleware.ts — instantly rather than lagging behind. Only fires
        // on an actual change, mirroring the old app's model where a zone flip only ever
        // happened as a side effect of a real navigation. The ack's player snapshot IS applied
        // (via applyUpdate, revision-guarded against a later, faster action's response landing
        // first): registry.ts's broadcast for this mutation excludes the acting socket, so this
        // ack is the ONLY way THIS tab ever learns its own aura just changed — other tabs on
        // the same session still get it via that broadcast.
        if (nextScreen !== state.screen)
            void request('player:screen', { screen: nextScreen }).then(res => {
                // `res.data.player` is defensively checked (not just `res.ok`): a malformed or
                // unexpected response must never be able to crash applyUpdate.
                if (res.ok && res.data.player)
                    get().applyUpdate(res.data.player);
            });

        set({
            screen: nextScreen,
            highscoreRaceFilter: opts?.raceFilter !== undefined ? opts.raceFilter : state.highscoreRaceFilter,
            // A flash is a one-shot message tied to the action that produced it (old app's
            // session flash was deleted the instant it was read, so it could never survive a
            // navigation by construction) — clear it here so it doesn't linger indefinitely
            // across unrelated screen changes the way it did before this fix.
            flash: null,
        });
    },

    setFlash(flash) {
        set({ flash });
    },

    setNotice(notice) {
        set({ notice });
    },

    setStatus(status) {
        set({ status });
    },

    toggleSound() {
        const next = !get().soundEnabled;
        writeStoredSoundEnabled(next);
        set({ soundEnabled: next });
    },
}));
