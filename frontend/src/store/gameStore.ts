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
            if (!state.player)
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

        // Fire-and-forget: tells the server the Battle screen was actually left, so
        // syncZoneAuras (player.service.ts) can start the combat aura's regen-blocking grace
        // period from THIS moment instead of the player's last fight — otherwise simply
        // pausing between fights while still on the Battle screen would let regen silently
        // resume mid-encounter. Naturally never fires while ambushed: pinScreen forces
        // `nextScreen` back to 'battle' in that case, so it never differs from 'battle'. The
        // response is intentionally ignored — the server's own broadcast/exact-expiry-timer
        // mechanism (see registry.ts/tick.ts) keeps every tab's effects list correct within a
        // few seconds regardless.
        if (state.screen === 'battle' && nextScreen !== 'battle')
            void request('battle:leave', {});

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
