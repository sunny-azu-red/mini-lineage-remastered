import { describe, it, expect, vi, beforeEach } from 'vitest';
import { statisticsRepository } from '@/repository/statistics.repository';
import { dbPool } from '@/config/database.config';
import { logger } from '@/config/logger.config';

vi.mock('@/config/database.config', () => ({
    dbPool: {
        execute: vi.fn(),
    },
}));

vi.mock('@/config/logger.config', () => ({
    logger: { error: vi.fn(), debug: vi.fn(), warn: vi.fn(), info: vi.fn() },
}));

describe('statisticsRepository', () => {
    beforeEach(async () => {
        vi.mocked(dbPool.execute).mockReset().mockResolvedValue([[]] as never);
        await statisticsRepository.flush(); // drain whatever a previous test left buffered
        vi.clearAllMocks();
    });

    describe('increment and flush', () => {
        it('buffers a counter rather than writing it immediately', () => {
            statisticsRepository.increment('total_players', 1);

            expect(dbPool.execute).not.toHaveBeenCalled();
        });

        it('writes one row per field on flush, defaulting the amount to 1', async () => {
            statisticsRepository.increment('total_players');
            await statisticsRepository.flush();

            expect(dbPool.execute).toHaveBeenCalledWith(
                expect.stringContaining('INSERT INTO statistics (name, value) VALUES (?, ?) '),
                ['total_players', 1]
            );
        });

        it('aggregates repeated increments of one field into a single row', async () => {
            statisticsRepository.increment('total_battles');
            statisticsRepository.increment('total_battles', 3);
            await statisticsRepository.flush();

            expect(dbPool.execute).toHaveBeenCalledTimes(1);
            expect(dbPool.execute).toHaveBeenCalledWith(expect.any(String), ['total_battles', 4]);
        });

        it('batches every buffered field into one statement', async () => {
            statisticsRepository.increment('total_deaths');
            statisticsRepository.increment('total_adena', 250);
            await statisticsRepository.flush();

            const [sql, params] = vi.mocked(dbPool.execute).mock.calls[0];
            expect(sql).toContain('VALUES (?, ?), (?, ?)');
            expect(sql).toContain('ON DUPLICATE KEY UPDATE value = value + VALUES(value)');
            expect(params).toEqual(['total_deaths', 1, 'total_adena', 250]);
        });

        it('does not go to the database with nothing buffered', async () => {
            await statisticsRepository.flush();

            expect(dbPool.execute).not.toHaveBeenCalled();
        });

        // Call sites are fire-and-forget, so a rejection escaping flush would be an UNHANDLED
        // rejection — which terminates the process. A counter is not worth a crash.
        it('logs one line and re-queues the batch when the write fails, retrying on the next flush', async () => {
            const err = Object.assign(new Error('read ECONNRESET'), { code: 'ECONNRESET' });
            vi.mocked(dbPool.execute).mockRejectedValueOnce(err);

            statisticsRepository.increment('total_battles', 3);
            statisticsRepository.increment('total_deaths');

            await expect(statisticsRepository.flush()).resolves.toBeUndefined();
            expect(logger.error).toHaveBeenCalledTimes(1);
            expect(logger.error).toHaveBeenCalledWith(
                expect.objectContaining({ err, counters: 2 }),
                expect.stringContaining('Statistics flush failed')
            );

            await statisticsRepository.flush();
            expect(dbPool.execute).toHaveBeenLastCalledWith(
                expect.any(String),
                ['total_battles', 3, 'total_deaths', 1]
            );
        });

        it('merges a re-queued counter with one buffered during the outage', async () => {
            vi.mocked(dbPool.execute).mockRejectedValueOnce(new Error('down'));

            statisticsRepository.increment('total_battles', 2);
            await statisticsRepository.flush();
            statisticsRepository.increment('total_battles', 5);
            await statisticsRepository.flush();

            expect(dbPool.execute).toHaveBeenLastCalledWith(expect.any(String), ['total_battles', 7]);
        });

        it('stays silent about a failure that never happened', async () => {
            statisticsRepository.increment('total_deaths');
            await statisticsRepository.flush();

            expect(logger.error).not.toHaveBeenCalled();
        });
    });

    describe('getAll', () => {
        it('should return null if total_players is 0', async () => {
            vi.mocked(dbPool.execute).mockResolvedValue([[
                { name: 'total_players', value: 0 }
            ]] as any);
            const stats = await statisticsRepository.getAll();
            expect(stats).toBeNull();
        });

        it('should return mapped stats if total_players > 0', async () => {
            vi.mocked(dbPool.execute).mockResolvedValue([[
                { name: 'total_players', value: 5 },
                { name: 'total_adena', value: 1000 }
            ]] as any);
            const stats = await statisticsRepository.getAll();
            expect(stats?.total_players).toBe(5);
            expect(stats?.total_adena).toBe(1000);
        });

        it('should initialize missing fields with 0', async () => {
            vi.mocked(dbPool.execute).mockResolvedValue([[
                { name: 'total_players', value: 1 }
            ]] as any);
            const stats = await statisticsRepository.getAll();
            expect(stats?.total_deaths).toBe(0);
        });

        it('flushes buffered counters first, so a brand-new player does not read empty archives', async () => {
            vi.mocked(dbPool.execute).mockResolvedValue([[{ name: 'total_players', value: 1 }]] as never);
            statisticsRepository.increment('total_players');

            await statisticsRepository.getAll();

            const [insert, select] = vi.mocked(dbPool.execute).mock.calls;
            expect(insert[0]).toContain('INSERT INTO statistics');
            expect(select[0]).toContain('SELECT name, value FROM statistics');
        });

        it('should ignore unknown fields from database', async () => {
            vi.mocked(dbPool.execute).mockResolvedValue([[
                { name: 'total_players', value: 5 },
                { name: 'unknown_field', value: 99 }
            ]] as any);
            const stats = await statisticsRepository.getAll();
            expect((stats as any).unknown_field).toBeUndefined();
        });

    });
});
