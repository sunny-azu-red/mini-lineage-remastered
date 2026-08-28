import { create } from 'zustand';
import type {
    PlayerSnapshot,
    GameCatalog,
    FlashView,
    SocketErrorPayload,
    BattleFightResult,
    BattleNarrativeSnapshot,
    HydratePayload,
} from '@shared/contract';

export type ScreenId =
    | 'start' | 'home' | 'battle' | 'weapons' | 'armors' | 'inn' | 'suicide'
    | 'death' | 'character' | 'highscores' | 'statistics' | 'races' | 'error';

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
 * The screen is pinned to 'battle' whenever the player is currently ambushed — there is no other
 * screen to reach in the first place, so this is applied at the end of every action that sets
 * `screen` and/or `player`, using whatever the FINAL `player` value of that update is. This keeps
 * "screen is 'battle' whenever ambushed" true atomically after every single state transition
 * (navigation, hydrate/reconnect, a shop/battle mutation, a pushed update), not just some of them.
 */
function pinToBattleIfAmbushed(screen: ScreenId, player: PlayerSnapshot | null): ScreenId {
    return player?.ambushed ? 'battle' : screen;
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
            const wasDead = state.player?.dead ?? false;
            const isDead = p.player?.dead ?? false;
            // NOTE: the server (src/socket/index.ts's connection handler) always sends a
            // non-null PlayerSnapshot — even for a session with no character yet, it's
            // `buildPlayerSnapshot({})`, i.e. `{ started: false, ... }` — never a literal
            // `null`. `HydratePayload.player` is typed `PlayerSnapshot | null` for API
            // generality (and so `game:restart`'s reset-in-place result composes cleanly), but
            // `started` — not null-ness — is the real "has a character" signal on both the
            // very first hydrate and every subsequent one.
            const wasStarted = state.player?.started ?? false;
            const isStarted = p.player?.started ?? false;

            let screen = state.screen;
            if (isFirstHydrateEver) {
                screen = !isStarted ? 'start' : isDead ? 'death' : 'home';
            } else if (isDead && !wasDead) {
                // The core "refresh mid-ambush is boring/harmless" invariant only cares about
                // one transition: a reconnect that reveals the player just died. Every other
                // reconnect must leave the current screen alone.
                screen = 'death';
            } else if (wasStarted && !isStarted) {
                // A reset landed (game:restart or a highscore submit, both of which resolve
                // `resetPlayer()` server-side and push a fresh hydrate) — route back to 'start'
                // exactly like a brand-new, never-started visitor, rather than leaving the
                // screen stuck on wherever the just-reset player used to be (e.g. 'death').
                screen = 'start';
            }

            // Sync unconditionally (including to `null`) on EVERY hydrate, not just the first —
            // `PlayerSnapshot.lastBattle` is now the server-persisted source of truth, so a
            // reconnect must reflect it exactly: a genuine last-fight narrative on any reconnect
            // after fighting, but also back to `null` after a reset (game:restart/highscore
            // submit already clears `lastBattleNarrative` server-side) rather than leaving a
            // stale narrative from the previous character on screen.
            const lastBattle: BattleNarrativeSnapshot | null = p.player?.lastBattle ?? null;

            return { player: p.player, catalog: p.catalog, screen: pinToBattleIfAmbushed(screen, p.player), lastBattle };
        });
    },

    applyUpdate(p) {
        set(state => {
            if (!state.player)
                return {};
            const player = { ...state.player, ...p };
            return { player, screen: pinToBattleIfAmbushed(state.screen, player) };
        });
    },

    applyMutation(player, flash = null) {
        set(state => ({ player, flash, notice: null, screen: pinToBattleIfAmbushed(state.screen, player) }));
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
            screen: pinToBattleIfAmbushed(state.screen, result.player),
        }));
    },

    navigate(screen, opts) {
        set(state => ({
            screen: pinToBattleIfAmbushed(screen, state.player),
            highscoreRaceFilter: opts?.raceFilter !== undefined ? opts.raceFilter : state.highscoreRaceFilter,
        }));
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
