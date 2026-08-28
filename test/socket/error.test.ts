import { describe, it, expect, vi } from 'vitest';
import { SocketError, toAckError } from '@/socket/error';
import { logger } from '@/config/logger.config';

vi.mock('@/config/logger.config', () => ({
    logger: {
        error: vi.fn(),
        debug: vi.fn(),
        warn: vi.fn(),
        info: vi.fn(),
    },
}));

describe('SocketError', () => {
    it('carries code, message, and optional retryAfterMs', () => {
        const err = new SocketError('DEAD', 'fight first', 1234);
        expect(err.code).toBe('DEAD');
        expect(err.message).toBe('fight first');
        expect(err.retryAfterMs).toBe(1234);
        expect(err.name).toBe('SocketError');
        expect(err).toBeInstanceOf(Error);
    });
});

describe('toAckError', () => {
    it('maps a SocketError to its own ack payload without logging', () => {
        const err = new SocketError('DEAD', 'you are dead');
        const ack = toAckError(err);

        expect(ack).toEqual({ ok: false, error: { code: 'DEAD', message: 'you are dead', retryAfterMs: undefined } });
        expect(logger.error).not.toHaveBeenCalled();
    });

    it('maps an unexpected error to a generic INTERNAL payload and logs it', () => {
        const err = new Error('boom');
        const ack = toAckError(err);

        expect(ack).toEqual({ ok: false, error: { code: 'INTERNAL', message: 'Something went wrong. Please try again.' } });
        expect(logger.error).toHaveBeenCalledWith({ err }, 'Unhandled socket error');
    });

    it('never leaks the internal error message to the client', () => {
        const err = new Error('leaked secret database password');
        const ack = toAckError(err);

        expect(JSON.stringify(ack)).not.toContain('leaked secret');
    });

    it('handles non-Error thrown values', () => {
        const ack = toAckError('a plain string throw');
        expect(ack.error.code).toBe('INTERNAL');
        expect(logger.error).toHaveBeenCalled();
    });
});
