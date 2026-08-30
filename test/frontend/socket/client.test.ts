import { describe, it, expect, vi, beforeEach } from 'vitest';

// socket.io-client is replaced wholesale: `io()` runs at module scope in client.ts, so the fake
// has to exist before that import is evaluated (hence vi.hoisted + a top-level await import
// below, the same pattern the component tests use for '@/socket/client').
const { ioMock, fakeSocket, emitWithAckMock, timeoutMock } = vi.hoisted(() => {
    const emitWithAckMock = vi.fn();
    const timeoutMock = vi.fn(() => ({ emitWithAck: emitWithAckMock }));
    const fakeSocket = {
        connect: vi.fn(),
        timeout: timeoutMock,
    };
    return { ioMock: vi.fn(() => fakeSocket), fakeSocket, emitWithAckMock, timeoutMock };
});

vi.mock('socket.io-client', () => ({ io: ioMock }));

const { socket, bootstrapSession, connectSocket, request } = await import('@/socket/client');

const OFFLINE_ACK = {
    ok: false,
    error: { code: 'INTERNAL', message: '⭕ You got disconnected from the realm, the backend is offline.' },
};

describe('socket client', () => {
    beforeEach(() => {
        // Deliberately NOT vi.clearAllMocks(): `io()` runs exactly once, at module-evaluation
        // time, so wiping its call record would erase the very thing the first test asserts on.
        fakeSocket.connect.mockClear();
        timeoutMock.mockClear();
        emitWithAckMock.mockReset();
    });

    it('creates the singleton socket with autoConnect disabled (bootstrapSession must run first)', () => {
        expect(ioMock).toHaveBeenCalledWith({ autoConnect: false });
        expect(socket).toBe(fakeSocket);
    });

    describe('bootstrapSession', () => {
        it('GETs /api/bootstrap with same-origin credentials so express-session can set its cookie', async () => {
            const fetchMock = vi.fn().mockResolvedValue({ ok: true });
            vi.stubGlobal('fetch', fetchMock);

            await bootstrapSession();

            expect(fetchMock).toHaveBeenCalledWith('/api/bootstrap', { credentials: 'same-origin' });
            vi.unstubAllGlobals();
        });

        it('never connects the socket by itself — that is connectSocket()\'s job, strictly afterwards', async () => {
            vi.stubGlobal('fetch', vi.fn().mockResolvedValue({ ok: true }));

            await bootstrapSession();

            expect(fakeSocket.connect).not.toHaveBeenCalled();
            vi.unstubAllGlobals();
        });
    });

    describe('connectSocket', () => {
        it('opens the (autoConnect:false) socket', () => {
            connectSocket();

            expect(fakeSocket.connect).toHaveBeenCalledTimes(1);
        });
    });

    describe('request', () => {
        it('emits through a 10s timeout wrapper and resolves the server ack unchanged', async () => {
            const ack = { ok: true, data: { player: null, flash: null } };
            emitWithAckMock.mockResolvedValue(ack);

            const result = await request('shop:purchase', { type: 'food', itemId: 1 });

            expect(timeoutMock).toHaveBeenCalledWith(10_000);
            expect(emitWithAckMock).toHaveBeenCalledWith('shop:purchase', { type: 'food', itemId: 1 });
            expect(result).toBe(ack);
        });

        it('resolves a failure ack unchanged too (a rejected action is not a transport error)', async () => {
            const ack = { ok: false, error: { code: 'RATE_LIMITED', message: 'Too many requests.' } };
            emitWithAckMock.mockResolvedValue(ack);

            await expect(request('battle:fight', {})).resolves.toBe(ack);
        });

        // Callers never need their own try/catch: an ack timeout (or any transport-level throw)
        // has to come back as a normal Ack failure value, never as a rejected promise.
        it('converts an emitWithAck rejection (ack timeout / dead transport) into the INTERNAL offline ack', async () => {
            emitWithAckMock.mockRejectedValue(new Error('operation has timed out'));

            await expect(request('battle:fight', {})).resolves.toEqual(OFFLINE_ACK);
        });

        it('converts a synchronous throw from timeout() into the same INTERNAL offline ack', async () => {
            timeoutMock.mockImplementationOnce(() => {
                throw new Error('socket destroyed');
            });

            await expect(request('statistics:get', {})).resolves.toEqual(OFFLINE_ACK);
        });
    });
});
