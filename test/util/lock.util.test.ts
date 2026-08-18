import { describe, it, expect, vi, beforeEach } from 'vitest';
import { acquireSessionLock } from '@/util/lock.util';

describe('SessionLock (util/lock.util.ts)', () => {
    beforeEach(() => {
        // Since the lock map is module-level, it persists between tests.
        // We could export it for testing or just rely on new session IDs.
    });

    it('should acquire lock immediately for a new session', async () => {
        const sessionId = 'session-1';
        const release = await acquireSessionLock(sessionId);
        expect(release).toBeTypeOf('function');
        release();
    });

    it('should serialize concurrent requests for the same session', async () => {
        const sessionId = 'session-2';
        let order: number[] = [];

        // Acquire lock 1
        const release1 = await acquireSessionLock(sessionId);
        
        // Try to acquire lock 2 (this should wait)
        const lock2Promise = acquireSessionLock(sessionId).then(async (release2) => {
            order.push(2);
            release2();
        });

        order.push(1);
        release1();

        await lock2Promise;

        expect(order).toEqual([1, 2]);
    });

    it('should allow different sessions to acquire locks independently', async () => {
        const sessionA = 'session-A';
        const sessionB = 'session-B';
        let order: string[] = [];

        const releaseA = await acquireSessionLock(sessionA);
        
        const lockBPromise = acquireSessionLock(sessionB).then(async (releaseB) => {
            order.push('B');
            releaseB();
        });

        // Even though A is held, B should be able to acquire immediately (or very quickly)
        await lockBPromise;
        order.push('A');
        releaseA();

        expect(order).toEqual(['B', 'A']);
    });

    it('should handle many sequential requests', async () => {
        const sessionId = 'session-sequential';
        const count = 10;
        let lastCounter = 0;
        const tasks = [];

        for (let i = 1; i <= count; i++) {
            tasks.push(acquireSessionLock(sessionId).then(async (release) => {
                // Verify sequential order
                expect(lastCounter).toBe(i - 1);
                lastCounter = i;
                release();
            }));
        }

        await Promise.all(tasks);
        expect(lastCounter).toBe(count);
    });
});
