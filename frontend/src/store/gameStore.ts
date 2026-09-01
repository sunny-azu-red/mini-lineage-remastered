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

// The only screens a visitor with no character may reach.
const UNSTARTED_ALLOWED: ReadonlySet<ScreenId> = new Set(['start', 'statistics', 'races', 'highscores', 'error']);

// Screens a living character may never be on — 'death' would expose "Play Again?" to the living.
const STARTED_BLOCKED: ReadonlySet<ScreenId> = new Set(['start', 'statistics', 'races', 'death']);

// The single place every navigation rule is enforced. Death wins outright (checked first because
// killPlayer doesn't clear `ambushed`), then an active ambush, then living-vs-absent character.
function pinScreen(screen: ScreenId, player: PlayerSnapshot | null): ScreenId {
    if (player?.dead)
        return 'death';
    if (player?.ambushed)
        return 'battle';

    if (player?.started)
        return STARTED_BLOCKED.has(screen) ? 'home' : screen;

    return UNSTARTED_ALLOWED.has(screen) ? screen : 'start';
}

// Detects "a reset just landed", since a mutation's own ack and the server's push for it can
// arrive in either order and whichever loses the race must still catch the transition.
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
    /** The reconnect-safe narrative shape, populated by a fight ack and by every hydrate. */
    lastBattle: BattleNarrativeSnapshot | null;
    notice: SocketErrorPayload | null;
    soundEnabled: boolean;
    /** When the snapshot carrying the current `player.effects` landed, on this machine's clock. */
    effectsStampedAt: number;

    hydrate(p: HydratePayload): void;
    applyUpdate(p: Partial<PlayerSnapshot>): void;
    /** Moves the player in the SAME atomic update that commits the new snapshot — see callers. */
    applyMutation(player: PlayerSnapshot, flash?: FlashView | null, screen?: ScreenId): void;
    /** `battle:fight`'s ack carries more than a MutationResult, so it gets its own setter. */
    recordBattleResult(result: BattleFightResult): void;
    /** `raceFilter: undefined` leaves the filter alone, `null` clears it, a number sets it. */
    navigate(screen: ScreenId, opts?: { raceFilter?: number | null }): void;
    setFlash(f: FlashView | null): void;
    setNotice(n: SocketErrorPayload | null): void;
    setStatus(s: GameStore['status']): void;
    toggleSound(): void;
}

export const useGameStore = create<GameStore>((set, get) => {
    // Tells the server which screen we're on so it can classify the combat/resting zone. `started`
    // is passed in since `hydrate` calls this before the new player has been committed to the store.
    const reportScreen = (screen: ScreenId, started: boolean) => {
        if (!started)
            return;

        void request('player:screen', { screen }).then(res => {
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
        effectsStampedAt: Date.now(),

        hydrate(p) {
            set(state => {
                const isFirstHydrate = state.catalog === null;
                // Boot straight into whatever screen the URL names, so a deep link reports itself
                // ONCE instead of costing a second player:screen round trip once corrected later.
                const screen = isFirstHydrate
                    ? pinScreen(screenFromPath(location.pathname), p.player)
                    : deriveScreenAfterPlayerChange(state.player, p.player, state.screen);

                reportScreen(screen, Boolean(p.player?.started));

                // Synced unconditionally (including to null): lastBattle is server-persisted, so a
                // reset must clear it rather than leave the previous character's narrative on screen.
                return {
                    player: p.player, catalog: p.catalog, screen,
                    lastBattle: p.player?.lastBattle ?? null,
                    effectsStampedAt: Date.now(),
                };
            });
        },

        applyUpdate(p) {
            set(state => {
                if (!state.player || !p)
                    return {};

                // `revision` is monotonic so a push that lost the race to an earlier one gets
                // dropped instead of clobbering fresher state.
                if (p.revision !== undefined && state.player.revision !== undefined && p.revision < state.player.revision)
                    return {};

                const player = { ...state.player, ...p };

                return {
                    player,
                    screen: deriveScreenAfterPlayerChange(state.player, player, state.screen),
                    // Only when this push actually carried effects — remainingMs is relative to
                    // the snapshot that sent it, so restamping on an unrelated partial would
                    // silently restart every countdown.
                    effectsStampedAt: p.effects ? Date.now() : state.effectsStampedAt,
                };
            });
        },

        applyMutation(player, flash = null, screen) {
            set(state => ({
                player, flash, notice: null,
                screen: pinScreen(screen ?? state.screen, player),
                effectsStampedAt: Date.now(),
            }));
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
                effectsStampedAt: Date.now(),
            }));
        },

        navigate(screen, opts) {
            const state = get();
            const nextScreen = pinScreen(screen, state.player);

            if (nextScreen !== state.screen)
                reportScreen(nextScreen, Boolean(state.player?.started));

            set({
                screen: nextScreen,
                highscoreRaceFilter: opts?.raceFilter !== undefined ? opts.raceFilter : state.highscoreRaceFilter,
                flash: null, // one-shot, tied to the action that produced it — must not survive a navigation
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
