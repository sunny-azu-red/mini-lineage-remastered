import { describe, it, expect, vi, beforeEach } from 'vitest';
import type { Socket, Server as SocketIOServer } from 'socket.io';

vi.mock('@/socket/registry', () => ({ registerEvent: vi.fn() }));
vi.mock('@/repository/statistics.repository', () => ({
    statisticsRepository: { getAll: vi.fn() },
}));

import { registerEvent } from '@/socket/registry';
import { registerStatisticsHandlers } from '@/socket/handler/statistics.handler';
import { statisticsRepository } from '@/repository/statistics.repository';

function getDef() {
    const call = vi.mocked(registerEvent).mock.calls.find(c => (c[2] as any).event === 'statistics:get');
    if (!call)
        throw new Error('statistics:get not registered');

    return call[2] as any;
}

describe('statistics.handler', () => {
    const io = {} as SocketIOServer;
    const socket = {} as Socket;

    beforeEach(() => {
        vi.clearAllMocks();
        registerStatisticsHandlers(io, socket);
    });

    it('is a public read with no guards', () => {
        const def = getDef();
        expect(def.mode).toBe('read');
        expect(def.guards).toBeUndefined();
    });

    it('wraps statisticsRepository.getAll() in a StatisticsResponse', async () => {
        vi.mocked(statisticsRepository.getAll).mockResolvedValue({ total_players: 5 } as any);
        const result = await getDef().handler({} as any, {});
        expect(result).toEqual({ stats: { total_players: 5 } });
    });

    it('passes through null when there is no data yet', async () => {
        vi.mocked(statisticsRepository.getAll).mockResolvedValue(null);
        const result = await getDef().handler({} as any, {});
        expect(result).toEqual({ stats: null });
    });
});
