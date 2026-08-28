import type { SocketErrorCode, SocketErrorPayload } from '@shared/contract';
import { logger } from '@/config/logger.config';

/**
 * SocketError — thrown by guards/handlers to signal a well-known, user-facing
 * rejection. Anything else (a genuine bug) is treated as unexpected and never
 * leaks its details to the client — see toAckError().
 */
export class SocketError extends Error {
    constructor(public readonly code: SocketErrorCode, message: string, public readonly retryAfterMs?: number) {
        super(message);
        this.name = 'SocketError';
    }
}

/**
 * Normalizes any thrown value into an `Ack`-shaped error payload.
 * Known SocketErrors pass their code/message/retryAfterMs straight through;
 * anything else is logged server-side and replaced with a generic INTERNAL error.
 */
export function toAckError(err: unknown): { ok: false; error: SocketErrorPayload } {
    if (err instanceof SocketError)
        return { ok: false, error: { code: err.code, message: err.message, retryAfterMs: err.retryAfterMs } };

    logger.error({ err }, 'Unhandled socket error');

    return { ok: false, error: { code: 'INTERNAL', message: 'Something went wrong. Please try again.' } };
}
