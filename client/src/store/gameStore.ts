import { create } from 'zustand';
import type {
    PlayerSnapshot,
    GameCatalog,
    FlashView,
    SocketErrorPayload,
    BattleFightResult,
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

export interface GameStore {
    status: 'connecting' | 'ready' | 'disconnected';
    player: PlayerSnapshot | null;
    catalog: GameCatalog | null;
    screen: ScreenId;
    highscoreRaceFilter: number | null;
    flash: FlashView | null;
    lastBattle: BattleFightResult | null;
    notice: SocketErrorPayload | null;
    soundEnabled: boolean;

    hydrate(p: HydratePayload): void;
    applyUpdate(p: Partial<PlayerSnapshot>): void;
    applyMutation(player: PlayerSnapshot, flash?: FlashView | null): void;
    /**
     * `battle:fight`'s ack carries strictly more than a `MutationResult` (outcome, narrative,
     * ambushed/died flags, a resolved sound) — this is the dedicated setter for it, alongside
     * `applyMutation`, rather than overloading that one's signature. Also stamps `lastBattle` so
     * `BattleScreen`/`AmbushBanner` can render the fight's narrative, and clears `notice` exactly
     * like `applyMutation` does.
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

            return { player: p.player, catalog: p.catalog, screen };
        });
    },

    applyUpdate(p) {
        set(state => (state.player ? { player: { ...state.player, ...p } } : {}));
    },

    applyMutation(player, flash = null) {
        set({ player, flash, notice: null });
    },

    recordBattleResult(result) {
        set({ player: result.player, flash: result.flash, lastBattle: result, notice: null });
    },

    navigate(screen, opts) {
        set(state => ({
            screen,
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
