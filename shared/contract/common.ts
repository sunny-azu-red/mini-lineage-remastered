import type { PlayerSnapshot } from './player';

export type SoundName = 'crit' | 'eat' | 'level' | 'death' | 'buy' | 'start' | 'ambush';

/**
 * Every screen the client can be on. Shared between frontend (gameStore.ts's navigation state
 * machine) and backend (PlayerState.currentScreen, used by syncZoneAuras to classify combat vs
 * resting zones exactly like the old game's URL-path-based zone.middleware.ts did — see
 * game.constant.ts's TICK_CONFIG.combatZones/restingZones).
 */
export type ScreenId =
    | 'start' | 'home' | 'battle' | 'weapons' | 'armors' | 'inn' | 'suicide'
    | 'death' | 'character' | 'highscores' | 'statistics' | 'races' | 'error';

export type SocketErrorCode =
    | 'UNAUTHENTICATED'   // no session id on the handshake
    | 'SESSION_EXPIRED'   // session row vanished from the store
    | 'INVALID_PAYLOAD'   // Zod rejected it
    | 'RATE_LIMITED'
    | 'NOT_STARTED'       // no character yet
    | 'ALREADY_STARTED'   // character already exists
    | 'DEAD'              // action requires a living character
    | 'NOT_DEAD'          // action requires a dead character
    | 'INELIGIBLE'        // e.g. coward/cheater trying to post a highscore
    | 'INTERNAL';

export interface SocketErrorPayload {
    code: SocketErrorCode;
    message: string;
    retryAfterMs?: number; // only meaningful for RATE_LIMITED
}

export type Ack<T> =
    | { ok: true; data: T }
    | { ok: false; error: SocketErrorPayload };

export interface FlashView {
    text: string; // may contain server-composed HTML (<span class="xp">...), see narrative-safety invariant
    type: 'success' | 'danger' | 'info' | 'warning';
    sound?: SoundName;
}

/** Standard shape for the simple mutating actions (shop purchase, suicide, game start). */
export interface MutationResult {
    player: PlayerSnapshot;
    flash: FlashView | null;
}
