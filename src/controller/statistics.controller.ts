import { NextFunction, Request, Response } from 'express';
import { statisticsRepository } from '@/repository/statistics.repository';
import { renderStatisticsView } from '@/view/statistics.view';

export const getStatistics = async (req: Request, res: Response, next: NextFunction) => {
    const stats = await statisticsRepository.getAll();

    res.send(renderStatisticsView(stats));
};
