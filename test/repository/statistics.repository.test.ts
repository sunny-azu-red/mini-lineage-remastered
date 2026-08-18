import { describe, it, expect, vi, beforeEach } from 'vitest';
import { statisticsRepository } from '@/repository/statistics.repository';
import { dbPool } from '@/config/database.config';

vi.mock('@/config/database.config', () => ({
    dbPool: {
        execute: vi.fn(),
    },
}));

describe('statisticsRepository', () => {
    beforeEach(() => {
        vi.clearAllMocks();
    });

    describe('increment', () => {
        it('should execute INSERT statement with correct parameters', async () => {
            await statisticsRepository.increment('total_players', 1);
            expect(dbPool.execute).toHaveBeenCalledWith(
                expect.stringContaining('INSERT INTO statistics'),
                ['total_players', 1, 1]
            );
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
