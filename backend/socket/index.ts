import type { Server as HttpServer } from 'http';
import { Server as SocketIOServer, Socket } from 'socket.io';
import type { RequestHandler } from 'express';
import type { PlayerState } from '@/interface';
import { getSessionData } from '@/util/session-store.util';
import { logger } from '@/config/logger.config';
import { trackSocket, untrackSocket, emitHydrate } from './emitter';
import { startTickLoop, refreshExpiryTimers } from './tick';
import { buildPlayerSnapshot } from './serializer/player.serializer';
import { buildGameCatalog } from './serializer/catalog.serializer';
import { registerGameHandlers } from './handler/game.handler';
import { registerBattleHandlers } from './handler/battle.handler';
import { registerShopHandlers } from './handler/shop.handler';
import { registerPlayerHandlers } from './handler/player.handler';
import { registerHighscoresHandlers } from './handler/highscores.handler';
import { registerStatisticsHandlers } from './handler/statistics.handler';
import { registerCheatHandler } from './handler/cheat.handler';

const REGISTRARS = [
    registerGameHandlers, registerBattleHandlers, registerShopHandlers, registerPlayerHandlers,
    registerHighscoresHandlers, registerStatisticsHandlers, registerCheatHandler,
];

/** The sole transport for client->server actions and server->client push. */
export function initSocketService(server: HttpServer, sessionMiddleware: RequestHandler): SocketIOServer {
    const io = new SocketIOServer(server, { cors: { origin: false } });

    io.use((socket, next) => {
        (sessionMiddleware as any)(socket.request, {}, next);
    });

    io.on('connection', (socket: Socket) => {
        const sessionId: string | undefined = (socket.request as any).session?.id;

        if (sessionId) {
            trackSocket(io, sessionId, socket.id);

            // Hydrate is provably non-mutating — read the store as-is, so even a mid-ambush
            // hard refresh is harmless.
            void (async () => {
                try {
                    const player = ((await getSessionData(sessionId)) ?? {}) as PlayerState;
                    refreshExpiryTimers(io, sessionId, player);
                    emitHydrate(io, sessionId, { player: buildPlayerSnapshot(player), catalog: buildGameCatalog() });
                } catch (err) {
                    logger.error({ err }, '[SOCKET] failed to build hydrate payload on connect');
                }
            })();

            socket.on('disconnect', () => untrackSocket(sessionId, socket.id));
        }

        for (const register of REGISTRARS)
            register(io, socket);
    });

    startTickLoop(io);

    return io;
}
