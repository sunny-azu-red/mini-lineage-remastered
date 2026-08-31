import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';

const { requestMock } = vi.hoisted(() => ({ requestMock: vi.fn() }));
vi.mock('@/socket/client', () => ({ request: requestMock }));

const { useGameStore } = await import('@/store/gameStore');
const { syncClock } = await import('@/socket/clock');

/**
 * `EffectView.expiresAt` is an absolute SERVER epoch, so the client has to know how far the two
 * clocks are apart before it can count one down. These tests drive the SNTP four-timestamp
 * estimate (RFC 5905 §8) with synthetic clocks, so the recovered offset can be checked against a
 * skew that is known exactly.
 */

const LOCAL_START = 1_700_000_000_000;

/**
 * Replaces Date.now() with a controllable local clock and answers `time:sync` as a server whose
 * clock sits `skew` ms away, taking `latency` ms in each direction and `serverWork` ms to answer.
 */
function fakeExchange({ skew, latency, serverWork = 0 }: { skew: number; latency: number; serverWork?: number }) {
    let localNow = LOCAL_START;
    vi.spyOn(Date, 'now').mockImplementation(() => localNow);

    requestMock.mockImplementation(async () => {
        localNow += latency;                              // request in flight
        const receivedAt = localNow + skew;               // server reads its own clock
        localNow += serverWork;                           // server thinking time
        const sentAt = localNow + skew;
        localNow += latency;                              // answer in flight

        return { ok: true, data: { receivedAt, sentAt } };
    });
}

beforeEach(() => {
    requestMock.mockReset();
    useGameStore.setState({ clockOffsetMs: 0 });
});

afterEach(() => {
    vi.restoreAllMocks();
});

describe('syncClock', () => {
    it('recovers a known offset exactly when latency is symmetric', async () => {
        fakeExchange({ skew: 4_000, latency: 20 });

        await syncClock();

        expect(useGameStore.getState().clockOffsetMs).toBe(4_000);
    });

    it('recovers a server that is BEHIND the local clock', async () => {
        fakeExchange({ skew: -2_500, latency: 15 });

        await syncClock();

        expect(useGameStore.getState().clockOffsetMs).toBe(-2_500);
    });

    it('reports no offset when the two clocks already agree', async () => {
        fakeExchange({ skew: 0, latency: 40 });

        await syncClock();

        expect(useGameStore.getState().clockOffsetMs).toBe(0);
    });

    // The reason both server timestamps are sent: time spent answering must not be mistaken for
    // network latency, which would bias the offset by half of it.
    it('does not let the server\'s own processing time leak into the offset', async () => {
        fakeExchange({ skew: 1_000, latency: 10, serverWork: 500 });

        await syncClock();

        expect(useGameStore.getState().clockOffsetMs).toBe(1_000);
    });

    /**
     * Standard NTP practice: latency can only ever inflate an exchange, so the fastest one is the
     * least distorted. Here the middle sample is the quick one and carries the true offset; the
     * others are skewed by asymmetric delay, and averaging would land between them.
     */
    it('keeps the lowest-delay sample rather than the first, last, or an average', async () => {
        let localNow = LOCAL_START;
        vi.spyOn(Date, 'now').mockImplementation(() => localNow);

        // Only the outbound leg is slow, so these samples are genuinely distorted, not just slower.
        const legs = [{ out: 400, back: 0 }, { out: 5, back: 5 }, { out: 300, back: 0 }];
        let call = 0;
        requestMock.mockImplementation(async () => {
            const { out, back } = legs[call++];
            localNow += out;
            const at = localNow + 7_000;
            localNow += back;

            return { ok: true, data: { receivedAt: at, sentAt: at } };
        });

        await syncClock();

        expect(useGameStore.getState().clockOffsetMs).toBe(7_000);
    });

    it('leaves a previously measured offset alone when an exchange fails', async () => {
        useGameStore.setState({ clockOffsetMs: 1_234 });
        requestMock.mockResolvedValue({ ok: false, error: { code: 'INTERNAL', message: 'offline' } });

        await syncClock();

        expect(useGameStore.getState().clockOffsetMs).toBe(1_234);
    });

    it('abandons the sync if a later exchange in the batch fails', async () => {
        useGameStore.setState({ clockOffsetMs: 99 });
        let call = 0;
        requestMock.mockImplementation(async () => (call++ === 0
            ? { ok: true, data: { receivedAt: Date.now(), sentAt: Date.now() } }
            : { ok: false, error: { code: 'INTERNAL', message: 'dropped' } }));

        await syncClock();

        expect(useGameStore.getState().clockOffsetMs).toBe(99);
    });

    it('rounds to whole milliseconds', async () => {
        fakeExchange({ skew: 1_000, latency: 5, serverWork: 1 });

        await syncClock();

        expect(Number.isInteger(useGameStore.getState().clockOffsetMs)).toBe(true);
    });
});
