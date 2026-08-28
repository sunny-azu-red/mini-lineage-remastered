import type { Server as SocketIOServer, Socket } from 'socket.io';
import type { StatisticsResponse } from '@shared/contract';
import { registerEvent } from '../registry';
import { EmptyPayloadSchema } from '@/schema/socket.schema';
import { statisticsRepository } from '@/repository/statistics.repository';

/**
 * From statistics.controller.ts's getStatistics. Public — no guards.
 */
export function registerStatisticsHandlers(io: SocketIOServer, socket: Socket): void {
    registerEvent(io, socket, {
        event: 'statistics:get',
        schema: EmptyPayloadSchema,
        mode: 'read',
        handler: async (): Promise<StatisticsResponse> => {
            const stats = await statisticsRepository.getAll();

            return { stats };
        },
    });
}
