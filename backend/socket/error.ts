import type { SocketErrorCode, SocketErrorPayload } from '@shared/contract';
import { logger } from '@/config/logger.config';

/** A well-known, user-facing rejection. Anything else is a bug and never leaks to the client. */
export class SocketError extends Error {
    constructor(public readonly code: SocketErrorCode, message: string, public readonly retryAfterMs?: number) {
        super(message);
        this.name = 'SocketError';
    }
}

export function toAckError(err: unknown): { ok: false; error: SocketErrorPayload } {
    if (err instanceof SocketError)
        return { ok: false, error: { code: err.code, message: err.message, retryAfterMs: err.retryAfterMs } };

    logger.error({ err }, 'Unhandled socket error');

    return { ok: false, error: { code: 'INTERNAL', message: 'Something went wrong. Please try again.' } };
}
