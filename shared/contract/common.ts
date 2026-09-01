import type { PlayerSnapshot } from './player';

export type SoundName = 'crit' | 'eat' | 'level' | 'death' | 'buy' | 'start' | 'ambush';

// Shared with the server: PlayerState.currentScreen drives zone classification off this.
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
    /** May contain server-composed HTML — see the narrative-safety invariant on `Narrative`. */
    text: string;
    type: 'success' | 'danger' | 'info' | 'warning';
    sound?: SoundName;
}

/** The shape of every simple mutating action (shop purchase, suicide, game start). */
export interface MutationResult {
    player: PlayerSnapshot;
    flash: FlashView | null;
}
