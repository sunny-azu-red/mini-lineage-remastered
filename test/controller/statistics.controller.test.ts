import { describe, it, expect, vi, beforeEach } from 'vitest';
import { getStatistics } from '@/controller/statistics.controller';
import { statisticsRepository } from '@/repository/statistics.repository';
import * as statisticsView from '@/view/statistics.view';

vi.mock('@/repository/statistics.repository', () => ({
    statisticsRepository: {
        getAll: vi.fn().mockResolvedValue({ total_players: 10 }),
    }
}));

vi.mock('@/view/statistics.view', () => ({
    renderStatisticsView: vi.fn().mockReturnValue('statistics-view'),
}));

describe('statisticsController', () => {
    let req: any;
    let res: any;
    let next: any;

    beforeEach(() => {
        vi.clearAllMocks();
        req = {};
        res = {
            send: vi.fn(),
        };
        next = vi.fn();
    });

    it('should fetch statistics and render view', async () => {
        await getStatistics(req, res, next);
        expect(statisticsRepository.getAll).toHaveBeenCalled();
        expect(statisticsView.renderStatisticsView).toHaveBeenCalledWith({ total_players: 10 });
        expect(res.send).toHaveBeenCalledWith('statistics-view');
    });
});
