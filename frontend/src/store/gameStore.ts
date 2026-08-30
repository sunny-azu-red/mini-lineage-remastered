import { create } from 'zustand';
import { request } from '@/socket/client';
import { screenFromPath } from '@/routes';
import type {
    PlayerSnapshot, GameCatalog, FlashView, SocketErrorPayload,
    BattleFightResult, BattleNarrativeSnapshot, HydratePayload, ScreenId,
} from '@shared/contract';

export type { ScreenId };

const SOUND_STORAGE_KEY = 'mini_sound_enabled';

// localStorage throws in private-mode Safari and is absent in a plain 'node' test environment.
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
        // The preference just won't persist — non-fatal.
    }
}

/**
 * The only screens a visitor with no character may reach — the old cheatMiddleware's allowlist,
 * plus `error`: it is an out-of-band state with no URL, and hiding a failure behind the character
 * creation form would be worse than showing it.
 */
const UNSTARTED_ALLOWED: ReadonlySet<ScreenId> = new Set(['start', 'statistics', 'races', 'highscores', 'error']);

/**
 * Screens a player WITH a living character may never be on. `start` and the two pre-character
 * lore screens belong to character creation; `death` would otherwise expose "Play Again?" and let
 * a living character be wiped. The old app redirected all four to `/`.
 */
const STARTED_BLOCKED: ReadonlySet<ScreenId> = new Set(['start', 'statistics', 'races', 'death']);

/**
 * The single place every navigation rule is enforced — a direct port of the old app's global
 * `cheatMiddleware`, which ran on every request. Applied at the end of EVERY action that sets
 * `screen` and/or `player`, so the invariants hold after every transition no matter how it
 * arrived: an in-app link, a deep link, or the Back button.
 *
 * Order matters. Death wins outright, then an active ambush; only after those can a screen be
 * judged against a living or absent character. Death is checked FIRST because `killPlayer` does
 * not clear `ambushed`, so a corpse can still carry the flag — pinning that to `battle` would
 * strand it on a screen BattleScreen refuses to render for the dead, with every navigation
 * bouncing straight back.
 *
 * Because this catches everything, the header and character links can stay unconditionally
 * clickable — clicking them in a pinned state just harmlessly redirects back.
 */
function pinScreen(screen: ScreenId, player: PlayerSnapshot | null): ScreenId {
    if (player?.dead)
        return 'death';
    if (player?.ambushed)
        return 'battle';

    // Reaching here means the character is alive, or does not exist yet.
    if (player?.started)
        return STARTED_BLOCKED.has(screen) ? 'home' : screen;

    return UNSTARTED_ALLOWED.has(screen) ? screen : 'start';
}

/**
 * Detects "a reset just landed" identically on every path that receives a new player. A
 * mutation's own ack and the server's `state:update` push for that same mutation can arrive in
 * either order, so if only one path knew the transition, whichever lost the race would leave the
 * screen stuck.
 */
function deriveScreenAfterPlayerChange(
    prev: PlayerSnapshot | null,
    next: PlayerSnapshot | null,
    currentScreen: ScreenId,
): ScreenId {
    const wasReset = (prev?.started ?? false) && !(next?.started ?? false);

    return pinScreen(wasReset ? 'start' : currentScreen, next);
}

export interface GameStore {
    status: 'connecting' | 'ready' | 'disconnected';
    player: PlayerSnapshot | null;
    catalog: GameCatalog | null;
    screen: ScreenId;
    highscoreRaceFilter: number | null;
    flash: FlashView | null;
    /**
     * The reconnect-safe narrative shape — NOT the full `BattleFightResult` ack, whose
     * `player`/`flash` always come from `store.player`/`store.flash`. Populated by the live
     * fight ack AND by every hydrate from `PlayerSnapshot.lastBattle`.
     */
    lastBattle: BattleNarrativeSnapshot | null;
    notice: SocketErrorPayload | null;
    soundEnabled: boolean;

    hydrate(p: HydratePayload): void;
    applyUpdate(p: Partial<PlayerSnapshot>): void;
    /**
     * `screen` moves the player in the SAME atomic update that commits the new snapshot. Callers
     * mid-transition (game start, suicide) must use it rather than calling `navigate()` first:
     * `navigate` pins against whatever is in the store right now, which is still the OLD player
     * until this runs.
     */
    applyMutation(player: PlayerSnapshot, flash?: FlashView | null, screen?: ScreenId): void;
    /** `battle:fight`'s ack carries more than a MutationResult, so it gets its own setter. */
    recordBattleResult(result: BattleFightResult): void;
    /**
     * `raceFilter: undefined` (or no opts) leaves the filter alone, `null` clears it, a number
     * sets it — hence the three-way type.
     */
    navigate(screen: ScreenId, opts?: { raceFilter?: number | null }): void;
    setFlash(f: FlashView | null): void;
    setNotice(n: SocketErrorPayload | null): void;
    setStatus(s: GameStore['status']): void;
    toggleSound(): void;
}

export const useGameStore = create<GameStore>((set, get) => {
    /**
     * Tells the server which screen we're on so it can classify the combat/resting zone. The
     * ack's snapshot IS applied (revision-guarded): registry.ts excludes the acting socket from
     * its broadcast, so this ack is the only way this tab learns its own aura changed.
     *
     * `started` is passed in rather than read off the store because `hydrate` calls this from
     * inside its own `set` updater, before the new player has been committed.
     *
     * A player with no character has no zone to classify, and the server's handler is guarded by
     * requireStarted — reporting anyway is guaranteed to be rejected as NOT_STARTED and logged as
     * an error. Reachable from every pre-character screen (Game Start, Statistics, Races,
     * Highscores), so the guard belongs here, covering both call sites at once.
     */
    const reportScreen = (screen: ScreenId, started: boolean) => {
        if (!started)
            return;

        void request('player:screen', { screen }).then(res => {
            // Defensive on `res.data.player` too — a malformed response must never crash applyUpdate.
            if (res.ok && res.data.player)
                get().applyUpdate(res.data.player);
        });
    };

    return {
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
                // Every HydratePayload carries a catalog, so a null one doubles as "this is the
                // first hydrate this session" without a separate tracked field.
                const isFirstHydrate = state.catalog === null;
                // Boot straight into whatever screen the URL names, so a deep link reports itself
                // ONCE. Guessing 'home' here and letting useHistorySync correct it afterwards cost
                // a second `player:screen` a round trip later, which the server saw as a real
                // navigation. `screenFromPath` returns 'home' for '/', and pinScreen demotes that
                // to 'start' for a visitor with no character — so the old started-or-not special
                // case is subsumed. Read at call time, so no effect ordering can beat it.
                const screen = isFirstHydrate
                    ? pinScreen(screenFromPath(location.pathname), p.player)
                    : deriveScreenAfterPlayerChange(state.player, p.player, state.screen);

                // hydrate() itself stays a pure read; this fires a separate, real action.
                reportScreen(screen, Boolean(p.player?.started));

                // Synced unconditionally (including to null) on EVERY hydrate: lastBattle is
                // server-persisted, so a reset must clear it rather than leave the previous
                // character's narrative on screen.
                return { player: p.player, catalog: p.catalog, screen, lastBattle: p.player?.lastBattle ?? null };
            });
        },

        applyUpdate(p) {
            set(state => {
                if (!state.player || !p)
                    return {};

                // Mutation broadcasts, the periodic tick and exact expiry timers can all emit
                // for the same session, so an older push can land after a newer one. `revision`
                // is monotonic precisely so a stale one can be dropped instead of clobbering
                // fresher state (including `effects`).
                if (p.revision !== undefined && state.player.revision !== undefined && p.revision < state.player.revision)
                    return {};

                const player = { ...state.player, ...p };

                return { player, screen: deriveScreenAfterPlayerChange(state.player, player, state.screen) };
            });
        },

        applyMutation(player, flash = null, screen) {
            set(state => ({ player, flash, notice: null, screen: pinScreen(screen ?? state.screen, player) }));
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

            // Only on an actual change, mirroring the old model where a zone flip only ever
            // happened as a side effect of a real navigation.
            if (nextScreen !== state.screen)
                reportScreen(nextScreen, Boolean(state.player?.started));

            set({
                screen: nextScreen,
                highscoreRaceFilter: opts?.raceFilter !== undefined ? opts.raceFilter : state.highscoreRaceFilter,
                // A flash is one-shot and tied to the action that produced it, so it must never
                // survive a navigation.
                flash: null,
            });
        },

        setFlash: (flash) => set({ flash }),
        setNotice: (notice) => set({ notice }),
        setStatus: (status) => set({ status }),

        toggleSound() {
            const next = !get().soundEnabled;
            writeStoredSoundEnabled(next);
            set({ soundEnabled: next });
        },
    };
});
