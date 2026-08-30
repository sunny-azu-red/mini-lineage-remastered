import type { PlayerState } from '@/interface';
import { isGameStarted } from '@/service/player.service';
import { SocketError } from './error';

/** A per-event precondition on the current player; throws a SocketError on failure. */
export type Guard = (player: PlayerState) => void;

const guard = (code: ConstructorParameters<typeof SocketError>[0], message: string, fails: (p: PlayerState) => boolean): Guard =>
    (player) => {
        if (fails(player))
            throw new SocketError(code, message);
    };

export const requireStarted = guard('NOT_STARTED', "You haven't started your journey yet — create a character first.", p => !isGameStarted(p));
export const requireNotStarted = guard('ALREADY_STARTED', 'You already have a character. Restart if you want to begin again.', p => isGameStarted(p));
export const requireAlive = guard('DEAD', 'You are dead. There is nothing left to do but restart.', p => Boolean(p.dead));
export const requireDead = guard('NOT_DEAD', "You're still alive — this action is only for the fallen.", p => !p.dead);
export const requireHighscoreEligible = guard('INELIGIBLE', 'Cowards and cheaters cannot be immortalized on the highscores.', p => Boolean(p.coward || p.cheated));
