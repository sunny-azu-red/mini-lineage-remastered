import { request } from './client';
import { useGameStore } from '@/store/gameStore';

/**
 * Exchanges to run per sync. More would refine the estimate a little further; three is enough to
 * discard a single unlucky exchange, which is all this needs at one-second display granularity.
 */
const SAMPLES = 3;

/**
 * Measures how far the server's clock is from this machine's, using SNTP's four-timestamp estimate
 * (RFC 5905 §8):
 *
 *     offset = ((T2 - T1) + (T3 - T4)) / 2
 *     delay  = (T4 - T1) - (T3 - T2)
 *
 * where T1/T4 are client send/receive and T2/T3 are the server's receive/send. Subtracting the
 * server's own processing time (T3 - T2) is what stops it being mistaken for network latency.
 *
 * Keeps the sample with the LOWEST delay rather than averaging, which is standard NTP practice:
 * latency can only ever inflate an exchange, so the fastest one is the least distorted. The
 * remaining error is asymmetric routing — one direction slower than the other — which no
 * software-only method can correct for.
 *
 * A failed exchange leaves the previous offset in place. Resetting to zero would throw away a good
 * measurement because the socket happened to drop.
 */
export async function syncClock(): Promise<void> {
    let best = { delay: Infinity, offset: 0 };

    for (let i = 0; i < SAMPLES; i++) {
        const t1 = Date.now();
        const res = await request('time:sync', {});
        const t4 = Date.now();

        if (!res.ok)
            return;

        const { receivedAt: t2, sentAt: t3 } = res.data;
        const delay = (t4 - t1) - (t3 - t2);

        if (delay < best.delay)
            best = { delay, offset: ((t2 - t1) + (t3 - t4)) / 2 };
    }

    useGameStore.getState().setClockOffset(Math.round(best.offset));
}
