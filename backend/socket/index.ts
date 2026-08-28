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

/**
 * Initializes the socket-driven API — the sole transport for client->server actions/queries and
 * server->client push (plan decision A1). Now that the legacy Express+EJS app and its
 * `socket.service.ts` socket server have been demolished, this binds to the DEFAULT
 * Engine.IO path (`/socket.io`) — the transitional `/socket.io/v2` override that once avoided
 * colliding with that legacy server is gone (see git history for the prior parallel-run phase).
 */
export function initSocketService(server: HttpServer, sessionMiddleware: RequestHandler): SocketIOServer {
    const io = new SocketIOServer(server, {
        cors: { origin: false },
    });

    io.use((socket, next) => {
        (sessionMiddleware as any)(socket.request, {}, next);
    });

    io.on('connection', (socket: Socket) => {
        const req = socket.request as any;
        const sessionId: string | undefined = req.session?.id;

        if (sessionId) {
            trackSocket(io, sessionId, socket.id);

            // Hydrate is provably non-mutating — read whatever's in the store (or nothing)
            // and send it as-is. This is what makes even a mid-ambush hard refresh harmless.
            void (async () => {
                try {
                    const session = await getSessionData(sessionId);
                    const player = (session ?? {}) as PlayerState;

                    refreshExpiryTimers(io, sessionId, player);

                    emitHydrate(io, sessionId, { player: buildPlayerSnapshot(player), catalog: buildGameCatalog() });
                } catch (err) {
                    logger.error({ err }, '[SOCKET] failed to build hydrate payload on connect');
                }
            })();
        }

        socket.on('disconnect', () => {
            if (sessionId)
                untrackSocket(sessionId, socket.id);
        });

        registerGameHandlers(io, socket);
        registerBattleHandlers(io, socket);
        registerShopHandlers(io, socket);
        registerPlayerHandlers(io, socket);
        registerHighscoresHandlers(io, socket);
        registerStatisticsHandlers(io, socket);
        registerCheatHandler(io, socket);
    });

    startTickLoop(io);

    return io;
}
