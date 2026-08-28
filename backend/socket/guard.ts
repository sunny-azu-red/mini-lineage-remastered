import type { PlayerState } from '@/interface';
import { isGameStarted } from '@/service/player.service';
import { SocketError } from './error';

/**
 * Guards — small per-event preconditions operating on a PlayerState, each
 * throwing a SocketError on failure. A straight port of cheat.middleware.ts's
 * non-ambush-kill responsibilities (dead players restricted, uninitialized
 * players restricted, already-started players restricted), expressed as
 * composable checks instead of a URL allowlist.
 */
export type Guard = (player: PlayerState) => void;

export const requireStarted: Guard = (player) => {
    if (!isGameStarted(player))
        throw new SocketError('NOT_STARTED', "You haven't started your journey yet — create a character first.");
};

export const requireNotStarted: Guard = (player) => {
    if (isGameStarted(player))
        throw new SocketError('ALREADY_STARTED', 'You already have a character. Restart if you want to begin again.');
};

export const requireAlive: Guard = (player) => {
    if (player.dead)
        throw new SocketError('DEAD', 'You are dead. There is nothing left to do but restart.');
};

export const requireDead: Guard = (player) => {
    if (!player.dead)
        throw new SocketError('NOT_DEAD', "You're still alive — this action is only for the fallen.");
};

export const requireHighscoreEligible: Guard = (player) => {
    if (player.coward || player.cheated)
        throw new SocketError('INELIGIBLE', 'Cowards and cheaters cannot be immortalized on the highscores.');
};
